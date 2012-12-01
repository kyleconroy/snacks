require './environment'

set :root, File.dirname(__FILE__)
use Rack::Session::Cookie, :secret => SnacksConfig.xss_token
use(OmniAuth::Builder) { provider :google_apps, :domain => SnacksConfig.google_apps_domain }

Sequel::Model.plugin :timestamps
Sequel::Model.raise_on_save_failure = false

class Article < Sequel::Model
  many_to_one :user
  one_to_many :votes
  one_to_many :comments
  many_to_many :tags
  plugin :single_table_inheritance, :type
  attr_writer :taghash
  
  def validate
    errors.add(:text, "must be at least 5 chars") if text.nil? || text.length < 5
  end
  
  def score
    votes_dataset.sum(:value) || 0
  end
  
  def taghash
    {}
  end
  
  def vote_for(user)
    Vote.find(:user => user, :article => self) if user
  end
end

class Answer < Article; end

class Question < Article
  one_to_many :answers, :key => :article_id, :class => Answer
  attr_writer :taghash
  
  def validate
    super
    errors.add(:title, "must be at least 5 chars") if title.nil? || title.length < 5
  end
  
  def taghash
    @taghash || {}
  end
  
  def question
    self
  end
  
  def around_save
    db.transaction do
      begin
        super
        taghash.keys.each do |tagname|
          tag = Tag.find(:name => tagname)
          unless tag
            tag = Tag.new({:name => tagname}) 
            tag.save(:raise_on_failure => true)
          end
          taghash[tagname] == 'add' ? add_tag(tag) : remove_tag(tag)
        end
      rescue Sequel::ValidationFailed => e
        errors.add(:tag, e)
        raise Sequel::Rollback
      rescue Sequel::DatabaseError => e
        errors.add(:tag, "This article already has that tag.")
        raise Sequel::Rollback
      end
    end
  end
end

class Answer < Article
  many_to_one :question, :key => :article_id, :class => Question
end

class Comment < Sequel::Model
  many_to_one :article
  many_to_one :user
  
  def validate
    errors.add(:text, "must be at least 5 chars") if text.nil? || text.length < 5
  end
end

class Tag < Sequel::Model
  many_to_many :articles
  def validate
    errors.add(:name, "must be only lowercase letters, numbers and dashes") unless name =~ /^[a-z0-9]+(-[a-z0-9]+)*$/
    errors.add(:name, "is a duplicate of #{name}") if Tag.find(:name => name)
  end
end

class User < Sequel::Model
  one_to_many :questions
  one_to_many :answers
  one_to_many :comments
end

class Vote < Sequel::Model
  many_to_one :article
  many_to_one :user
  
  def validate
    errors.add(:value, "Cannot upvote or downvote more than once") if Vote.find(:user_id => user_id, :article_id => article_id)
  end
end

module SearchQuery
  def self.search(term)
    questions_search = DB[:articles].select { [ text, ts_text, id.as(question_id)] }
    answers_search = DB[:articles].where(:type => 'Answer').select { [text, ts_text, article_id.as(question_id) ] }
    questions_title_search = DB[:articles].where(:type => 'Question').select { [title, ts_title.as(ts_text), id.as(question_id)] }
    comments_search = DB[:comments].select { [text, ts_text, article_id.as(question_id)] }
    results = questions_search.union(comments_search).union(answers_search).union(questions_title_search)
    
    # not doing :* prefix matching. Preprocess query into what TSvector wants. spaces -> ? only letters, numbers, underscores and qmarks are left.
    query = term.gsub(/\s+/, '?').gsub(/[^\w\?]/, '')
    results = results.filter("ts_text @@ to_tsquery('english', ?::text)", query)
    results.select { [:question_id, ts_headline('english', :text, to_tsquery('english', query), 'MaxFragments=2').as(headline)] }
  end
end

module ParamHelpers
  def self.try_json(str)
    return nil if str.empty?
    JSON.parse(str)
  rescue JSON::ParserError => e
    nil
  end
end

class Unauthorized < Exception; end

error Unauthorized do
  [403, "Access Denied"]
end

def authenticate!
  unless session[:user_id]
    raise Unauthorized unless request.get?
    session[:back_page] = request.path_info
    redirect to('auth/google_apps')
  end
  @current_user = User[session[:user_id]]
end

def authenticate
  return authenticate! unless SnacksConfig.allow_anonymous_readers
  @current_user = User[session[:user_id]] if session[:user_id]
end

def authorize(authorized_user)
  raise Unauthorized unless @current_user == authorized_user
end

%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do
    auth = request.env['omniauth.auth']
    user = User.find_or_create(:uid => auth[:uid]) { |u| u.name = auth[:info][:name] }
    session[:user_id] = user.id
    if session[:back_page]
      back_page = session[:back_page]
      session[:back_page] = nil
      redirect to(back_page)
    else
      redirect to('/')
    end
  end
end

get '/logout' do
  session[:user_id] = nil
  redirect to('/')
end

get '/' do
  authenticate
  @tags = Tag.fetch("select tags.name, tags.id as id,
                      count(articles_tags.id) as count
                        from tags left join articles_tags on tags.id = articles_tags.tag_id
                          group by tags.id, tags.name order by count desc")
  @questions = Article.where(:type => 'Question').order(:created_at.desc)
  erb :index
end

post '/tags/create' do
  authenticate!
  @tag = Tag.new(:name => params[:name])
  @tag.save ? redirect(to('/tags')) : erb(:tags_index)
end

get '/tags' do
  authenticate
  @tag = Tag.new
  erb :tags_index
end

get '/tags/:tagname' do
  authenticate
  @tag = Tag.find(:name => params[:tagname])
  @questions = @tag.articles
  erb :questions_index
end

get '/questions/new' do
  authenticate!
  @question = Question.new
  erb :questions_new
end

get '/questions' do
  authenticate
  @questions = Question
  erb :questions_index
end

post '/questions/create' do
  authenticate!
  @question = Question.new(:text => params[:text], 
                           :title => params[:title],
                           :user => @current_user)
  @question.taghash = ParamHelpers.try_json(params[:taghash])
  @question.save ? redirect(to("/questions/#{@question.id}")) : erb(:questions_new)
end

get '/questions/:id' do
  authenticate
  @question = Article[params[:id]]
  erb :questions_show
end

post '/questions/:question_id/answers' do
  authenticate!
  @question = Question[params[:question_id]]
  @answer = Answer.new(:text => params[:text],
                      :user => @current_user,
                      :question => @question)
  @answer.save ? redirect(to("/questions/#{@question.id}")) : erb(:questions_show)
end

get '/articles/:id/edit' do
  authenticate!
  @article = Article[params[:id]]
  authorize(@article.user)
  erb :articles_edit
end

post '/articles/:id/update' do
  authenticate!
  @article = Article[params[:id]]
  authorize(@article.user)
  @article.text = params[:text]
  @article.title = params[:title]
  @article.taghash = ParamHelpers.try_json(params[:taghash])
  @article.save ? redirect(to("/questions/#{@article.id}")) : erb(:articles_edit)
end

post '/articles/:id/destroy' do
  authenticate!
  article = Article[params[:id]]
  authorize(article.user)
  article.destroy
  redirect(to("/"))
end

get '/users' do
  authenticate
  erb :users_index
end

get '/users/:id' do
  authenticate
  @user = User[params[:id]]
  erb :users_show
end

[['upvote', 1], ['downvote', -1]].each do |path, value|
  post '/articles/:article_id/' + path do
    authenticate!
    article = Article[params[:article_id]]
    vote = Vote.find(:article => article, :user => @current_user, :value => value)
    vote ? vote.destroy : Vote.create(:article => article, :user => @current_user, :value => value)
    article.score.to_json
  end
end

post '/articles/:article_id/comments' do
  authenticate!
  article = Article[params[:article_id]]
  @comment = Comment.new(:user => @current_user,
                        :text => params[:text],
                        :article => article)
  @question = article.question
  @comment.save ? redirect(to("/questions/#{@question.id}")) : erb(:questions_show)
end

post '/comments/:id/destroy' do
  authenticate!
  comment = Comment[params[:id]]
  question = comment.article.question
  authorize(comment.user)
  comment.destroy
  redirect(to("/questions/#{question.id}"))
end

get '/search' do
  authenticate
  @results = []
  @results = SearchQuery.search(params[:query]) if params[:query]
  erb :search
end
