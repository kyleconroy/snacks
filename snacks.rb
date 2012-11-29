require './environment'

set :root, File.dirname(__FILE__)
use Rack::Session::Cookie, :secret => SnacksConfiguration['xss_token']
use(OmniAuth::Builder) { provider :google_apps, :domain => SnacksConfiguration['google_apps_domain'] }

Sequel::Model.plugin :timestamps
Sequel::Model.raise_on_save_failure = false

class Article < Sequel::Model
  many_to_one :user
  one_to_many :votes
  one_to_many :comments
  many_to_many :tags
  plugin :single_table_inheritance, :type
  
  def validate
    errors.add(:text, "must be at least 5 chars") if text.empty? || text.length < 5
  end
  
  def score
    votes_dataset.sum(:value) || 0
  end
end

class Answer < Article; end

class Question < Article
  one_to_many :answers, :key => :article_id, :class => Answer
  
  attr_accessor :taghash
  
  def validate
    super
    errors.add(:title, "must be at least 5 chars") if title.empty? || title.length < 5
  end
  
  def around_save
    db.transaction do
      begin
      super
      (taghash || {}).keys.each do |tagname|
        tag = Tag.find(:name => tagname)
        tag = Tag.new({:name => tagname}) unless tag
        tag.save(:raise_on_failure => true)
        taghash[tagname] == 'add' ? add_tag(tag) : remove_tag(tag)
      end
      rescue Sequel::ValidationFailed => e
        errors.add(:tag, e)
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
    errors.add(:text, "must be at least 5 chars") if text.empty? || text.length < 5
  end
end

class Tag < Sequel::Model
  many_to_many :articles
  def validate
    errors.add(:name, "must be only lowercase letters, numbers and dashes") unless name =~ /^[a-z0-9]+(-[a-z0-9]+)*$/
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

def auth
  unless session[:user_id]
    session[:back_page] = request.path_info
    redirect to('auth/google_apps')
  end
  @current_user = User[session[:user_id]]
end

%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do
    auth = request.env['omniauth.auth']
    user = User.find_or_create(:uid => auth[:uid]) do |u|
      u.name = auth[:info][:name]
      u.created_at = Time.now
    end
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
  auth
  @tags = Tag.fetch("select tags.name, tags.id as id,
                      count(articles_tags.id) as count
                        from tags left join articles_tags on tags.id = articles_tags.tag_id
                          group by tags.id, tags.name order by count desc")
  @questions = Article.where(:type => 'Question').order(:created_at.desc)
  erb :index
end

post '/tags/create' do
  auth
  @tag = Tag.new(:name => params[:name])
  @tag.save ? redirect(to('/tags')) : erb(:tags_index)
end

get '/tags' do
  auth
  @tag = Tag.new
  erb :tags_index
end

get '/questions/new' do
  auth
  @question = Question.new
  erb :questions_new
end

post '/questions/create' do
  auth
  @question = Question.new(:text => params[:text], 
                           :title => params[:title],
                           :user => @current_user)
  @question.taghash = JSON.parse(params[:taghash]) unless params[:taghash].empty?
  @question.save ? redirect(to("/questions/#{@question.id}")) : erb(:questions_new)
end

get '/questions/:id' do
  auth
  @question = Article[params[:id]]
  erb :questions_show
end

post '/questions/:question_id/answers' do
  auth
  @question = Question[params[:question_id]]
  @answer = Answer.new(:text => params[:text],
                      :user => @current_user,
                      :question => @question)
  @answer.save ? redirect(to("/questions/#{@question.id}")) : erb(:questions_show)
end

get '/articles/:id/edit' do
  auth
  @article = Article[params[:id]]
  erb :articles_edit
end

post '/articles/:id/update' do
  auth
  @article = Article[params[:id]]
  @article.text = params[:text]
  @article.title = params[:title]
  @article.taghash = JSON.parse(params[:taghash]) unless params[:taghash].empty?
  @article.save ? redirect(to("/questions/#{@article.id}")) : erb(:articles_edit)
end

get '/users' do
  auth
  erb :users_index
end

get '/users/:id' do
  auth
  @user = User[params[:id]]
  erb :users_show
end

[['upvote', 1], ['downvote', -1]].each do |path, value|
  post '/articles/:article_id/' + path do
    auth
    article = Article[params[:article_id]]
    vote = Vote.find(:article => article, :user => @current_user, :value => value)
    vote ? vote.destroy : Vote.create(:article => article, :user => @current_user, :value => value)
    article.score.to_json
  end
end

post '/articles/:article_id/comments' do
  auth
  article = Article[params[:article_id]]
  @comment = Comment.new(:user => @current_user,
                        :text => params[:text],
                        :article => article)
  @question = article.is_a?(Answer) ? article.question : article
  @comment.save ? redirect(to("/questions/#{@question.id}")) : erb(:questions_show)
end

get '/search' do
  auth
  @results = []
  @results = SearchQuery.search(params[:query]) if params[:query]
  erb :search
end
