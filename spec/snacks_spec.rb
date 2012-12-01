require_relative 'setup'

describe 'model tests' do
  before :each do
    clean_db
  end
  
  it "validates that tags are lowercase, hyphens, and numbers" do
    Tag.new(:name => 'abc').should be_valid
    Tag.new(:name => 'abc2').should be_valid
    Tag.new(:name => 'abc-d').should be_valid
    Tag.new(:name => 'ab-bc-cd').should be_valid
        
    Tag.new(:name => 'Abcd').should_not be_valid
    Tag.new(:name => 'abc d').should_not be_valid
    Tag.new(:name => '-').should_not be_valid
    Tag.new(:name => 'a-').should_not be_valid
    Tag.new(:name => '-a').should_not be_valid
  end

  it "validates question title and body length" do
    q = Question.new()
    q.validate
    q.errors.keys.should include(:title)
    q.errors.keys.should include(:text)
    q = Question.new(:title => '1234', :text => '1234')
    q.validate
    q.errors.keys.should include(:title)
    q.errors.keys.should include(:text)
  end
  
  it "validates answer title and body length" do
    a = Answer.new(:text => '1234')
    a.validate
    a.errors.keys.should include(:text)
  end
  
  it "validates comment body" do
    c = Comment.new
    c.validate
    c.errors.keys.should include(:text)
    c = Comment.new(:text => 'foo')
    c.validate
    c.errors.keys.should include(:text)
  end
  
  it "deletes answers when the question is deleted" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => '12345', :text => '12345', :user => u)
    a = Answer.create(:question => q, :text => '12345', :user => u)
    expect { q.destroy }.to change { Answer.count }.by(-1)
  end
  
  it "deletes comments when the question or answer is deleted" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => '12345', :text => '12345', :user => u)
    c = Comment.create(:article => q, :user => u, :text => 'abcde')
    expect { q.destroy }.to change { Comment.count }.by(-1)
  end
  
  it "deletes article tag joins when the question or answer is deleted" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => '12345', :text => '12345', :user => u)
    q.add_tag(:name => 'newtag')
    expect { q.destroy }.to change { Tag.find(:name => 'newtag').articles.count }.by(-1)
  end
  
  it "sets created_at timestamps for users, questions, answers and comments" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    a = Article.create(:text => 'potato', :user => u)
    a.created_at.should_not be_nil
  end
  
  it "allows the tag hash to be passed on creation" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u,
      :taghash => {'new-tag' => 'add'})
    q.tags.should include(Tag.find(:name => 'new-tag'))
  end
  
  it "updates the tag hash on articles when it is set" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u)
    q.add_tag(Tag.create(:name => 'existing-tag'))
    q.taghash = {'existing-tag' => 'remove', 'new-tag' => 'add', 'non-existing-tag' => 'remove'}
    q.save.should be_true
    q.tags.should_not include(Tag.find(:name => 'existing-tag'))
    q.tags.should include(Tag.find(:name => 'new-tag'))
  end
  
  it "is transactional when saving associated tags fails" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u)
    q.taghash = {'invalid-tag-' => 'add'}
    q.text = "Change that should not be saved"
    q.save.should be_false
    q.errors.keys.should include(:tag)
    q.reload.text.should == "More description"
    
    q.taghash = {'valid-tag' => 'add'}
    q.text = "ivld"
    q.save.should be_false
    Tag.where(:name => 'valid-tag').should be_empty
  end
  
  it "can't tag an article twice with the same tag" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u)
    q.add_tag(:name => 'cookies')
    q.taghash = {'cookies' => 'add'}
    q.save.should be_false
    q.errors.keys.should include(:tag)
  end
  
  it "can search for a basic term" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u)
    SearchQuery.search('best snack').all.should == [{:question_id => q.id, :headline => 'What is the <b>best</b> <b>snack</b>'}]
  end
  
  it "can vote on a question only once" do
    u = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u)
    Vote.new(:user => u, :article => q, :value => 1).save.should be_true
    v = Vote.new(:user => u, :article => q, :value => 1)
    v.save.should be_false
    v.errors.keys.should include(:value)
  end
  
  it "has a score for each article" do
    u1 = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    u2 = User.create(:name => 'abcd', :uid => 'dude@dude.com')
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => u1)
    q.score.should == 0
    Vote.create(:user => u1, :article => q, :value => 1)
    q.score.should == 1
    Vote.create(:user => u2, :article => q, :value => -1)
    q.score.should == 0
  end
  
  it "uses tryJson which is resilient to invalid json" do
    ParamHelpers.try_json('').should == nil
    ParamHelpers.try_json('null').should == nil
    ParamHelpers.try_json('{}').should == {}
    ParamHelpers.try_json('{"a":"b","c":2}').should == {'a' => 'b', 'c' => 2}
  end
  
  it "validates that tags are unique" do
    Tag.create(:name => 'new-tag')
    t = Tag.new(:name => 'new-tag')
    t.save.should be_false
    t.errors.keys.should include(:name)
  end
end

describe 'browser tests' do
  include Capybara::DSL
  
  before :each do
    clean_db
    User.create(:uid => 'FAKE_TEST_UID', :name => 'The Test User')
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:google_apps, {:uid => 'FAKE_TEST_UID'})
    visit '/logout' # Need to get a new cookie
  end

  it "survives an empty search query" do
    visit '/'
    fill_in 'query', :with => ''
    click_button 'Search'
    # assert something!
  end
  
  it "lets you search for a basic term from a question" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "Epic Question 1"
    fill_in 'text', :with => 'I am a jelly donut'
    click_button 'Create Question'
    page.should have_content 'I am a jelly donut'
    visit '/'
    fill_in 'query', :with => 'jelly'
    click_button 'Search'
    
    page.should have_content 'jelly donut'
    click_link "jelly donut"
    page.should have_content "I am a jelly donut"
    page.should have_content "The Test User"
  end
  
  it "can create a tag" do
    visit '/auth/google_apps'
    visit '/tags'
    fill_in 'name', :with => 'an-invalid-tag-'
    click_button "Create Tag"
    Tag.where(:name => 'an-invalid-tag-').should be_empty
    page.should have_content("must be only lowercase letters, numbers and dashes")
    fill_in 'name', :with => 'a-valid-tag'
    click_button "Create Tag"
    Tag.where(:name => 'a-valid-tag').should_not be_empty
  end
  
  it "Displays validation errors on creating a question" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What"
    fill_in 'text', :with => "Pepperidge Farm Milano"
    click_button 'Create Question'
    page.should have_content "title must be at least 5 chars"
  end
  
  it "displays validation errors on editing a question" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => "Pepperidge Farm Milano"
    click_button 'Create Question'
    click_link "Edit"
    fill_in 'text', :with => 'abcd'
    click_button 'Save'
    page.current_path.should =~ /articles\/(\d)+\/update/
    page.should have_content "text must be at least 5 chars" 
  end
  
  it "should have editable titles" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => "Pepperidge Farm Milano"
    click_button 'Create Question'
    click_link "Edit"
    page.should have_css('input[value="What is the best snack?"]')
    fill_in 'title', :with => 'My New Title'
    click_button 'Save'
    page.current_path.should =~ /questions\/(\d)+$/
    Question.find(:text => "Pepperidge Farm Milano").title.should == 'My New Title'
  end
  
  it "can search for comments" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => "Pepperidge Farm Milano"
    click_button 'Create Question'
    within '#question' do
      fill_in 'text', :with => 'this is a comment body.'
      click_button "Post Comment"
    end
    within '#basic-search' do
      fill_in 'query', :with => "comment body"
      click_button "Search"
    end
    page.should have_content "comment body"
    click_link "comment body"
    page.current_path.should =~ /questions\/(\d)+$/
  end
  
  it "Displays validation errors on answering a question" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => 'I really want to know.'
    click_button 'Create Question'
    page.current_path.should =~ /questions\/(\d)+$/
    fill_in 'answer-text', :with => 'chip'
    click_button 'Post Answer'
    page.should have_content "text must be at least 5 chars"
  end
  
  it "only allows creator to edit an article" do
    visit '/auth/google_apps'
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => User.find(:uid => 'FAKE_TEST_UID'))
    visit "/questions/#{q.id}"
    within('#question') { page.should have_link('Edit') }
    OmniAuth.config.add_mock(:google_apps, {:uid => 'FAKE_TEST_UID_2'})
    visit '/logout'
    visit "/questions/#{q.id}"
    within('#question') { page.should_not have_link('Edit') }
    visit "/articles/#{q.id}/edit"
    page.body.should == "Access Denied"
    
    browser = Rack::Test::Session.new(Rack::MockSession.new(Sinatra::Application))
    browser.post "/articles/#{q.id}/update", nil, {"rack.session" => {"user_id" => User.find(:uid => 'FAKE_TEST_UID_2').id} }
    browser.last_response.should be_forbidden
  end
  
  it "only allows creator to delete an article" do
    visit '/auth/google_apps'
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => User.find(:uid => 'FAKE_TEST_UID'))

    visit "/articles/#{q.id}/edit"
    expect do
      click_button('Delete')
    end.to change{ Article.count }.by(-1)

    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => User.find(:uid => 'FAKE_TEST_UID'))
    
    OmniAuth.config.add_mock(:google_apps, {:uid => 'FAKE_TEST_UID_2'})
    visit '/logout'
    visit '/auth/google_apps'
    
    browser = Rack::Test::Session.new(Rack::MockSession.new(Sinatra::Application))
    browser.post "/articles/#{q.id}/destroy", nil, {"rack.session" => {"user_id" => User.find(:uid => 'FAKE_TEST_UID_2').id} }
    browser.last_response.should be_forbidden
  end
  
  it "only allows creator to delete a comment" do
    visit '/auth/google_apps'
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => User.find(:uid => 'FAKE_TEST_UID'))
    visit "/questions/#{q.id}"
    within ('#question') do
      fill_in 'text', :with => "I don't understand your question."
    end
    click_button 'Post Comment'
    within ('#question') do
      page.should have_content "Delete Comment"
    end
    
    OmniAuth.config.add_mock(:google_apps, {:uid => 'FAKE_TEST_UID_2'})
    visit '/logout'
    visit '/auth/google_apps'
    visit "/questions/#{q.id}"
    within ('#question') do
      page.should_not have_content "Delete Comment"
    end
    
    c = Comment.order(:id).last
    browser = Rack::Test::Session.new(Rack::MockSession.new(Sinatra::Application))
    browser.post "/comments/#{c.id}/destroy", nil, {"rack.session" => {"user_id" => User.find(:uid => 'FAKE_TEST_UID_2').id} }
    browser.last_response.should be_forbidden
    
    OmniAuth.config.add_mock(:google_apps, {:uid => 'FAKE_TEST_UID'})
    visit '/logout'
    visit '/auth/google_apps'
    visit "/questions/#{q.id}"
    within ('#question') do
      expect { click_button "Delete Comment" }.to change { Comment.count }.by(-1)
    end
    page.current_path.should =~ /questions\/(\d)+$/
  end
  
  it "can answer a question and edit it, but not tag it" do
     visit '/'
     click_link 'Add Question'
     fill_in 'title', :with => "What is the best snack?"
     fill_in 'text', :with => 'I really want to know.'
     click_button 'Create Question'
     page.current_path.should =~ /questions\/(\d)+$/
     fill_in 'answer-text', :with => 'chips ahoy'
     click_button 'Post Answer'
     within('.answer') do
       click_link 'Edit'
     end
     page.current_path.should =~ /articles\/(\d)+\/edit/
     page.should_not have_css('.tag-input')
   end
  
  it "searches over title" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "FINDME"
    fill_in 'text', :with => 'body of the question'
    click_button 'Create Question'

    visit '/'
    within '#basic-search' do
      fill_in 'query', :with => "FINDME"
      click_button "Search"
    end
    page.should have_content "FINDME"
  end
  
  it "can browse by tag" do
    q = Question.create(:title => 'What is the best snack?', :text => 'More description', :user => User.find(:uid => 'FAKE_TEST_UID'))
    q.add_tag(Tag.create(:name => 'new-tag'))
    visit '/tags/new-tag'
    page.should have_content 'What is the best snack?'
  end

  it "should allow anonymous browsing" do
    browser = Rack::Test::Session.new(Rack::MockSession.new(Sinatra::Application))

    Snacks.stub(:configuration).and_return({ 'allow_anonymous_readers' => true })
    browser.get "/"
    browser.last_response.should be_ok

    Snacks.stub(:configuration).and_return({ 'allow_anonymous_readers' => false })
    browser.get "/"
    browser.last_response.should be_redirect
  end

  it "handles 404s in a sane way" do

  end
  
  it "should persist comments after failing validation and show errors nearby"
  it "can't vote on own question"
  
  # less important below this line
  
  it "has pagination"
  it "jumps to the relevant answer section on a link"
end

