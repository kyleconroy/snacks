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
  
  it "can't vote on own question"
end

describe 'browser tests' do
  include Capybara::DSL

  #Capybara.javascript_driver = :webkit
  before :all do
    User.create(:uid => 'FAKE_TEST_UID', :name => 'The Test User',  :created_at => Time.now)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_apps] = OmniAuth::AuthHash.new({
        :provider => 'google_apps',
        :uid => 'FAKE_TEST_UID'
      })
  end
  
  before :each do
    clean_db
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
    page.current_path.should =~ /questions\/(\d)+/
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
    page.current_path.should =~ /questions\/(\d)+/
  end
  
  it "should allow anonymous browsing"
  it "should persist comments after failing validation and show errors nearby"
  it "can only add tags to questions and not answers"
  it "breaks if i try creating a question and not logged in"
  it "can search by tag"
  it "can delete a question or answer"
  it "only allows user to edit or delete"
  it "has pagination"
  it "jumps to the relevant answer section on a link"
  
  it "Displays validation errors on answering a question" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => 'I really want to know.'
    click_button 'Create Question'
    page.current_path.should =~ /questions\/(\d)+/
    fill_in 'answer-text', :with => 'chip'
    click_button 'Post Answer'
    page.should have_content "text must be at least 5 chars"
  end
  
  it "can answer a question" do
     visit '/'
     click_link 'Add Question'
     fill_in 'title', :with => "What is the best snack?"
     fill_in 'text', :with => 'I really want to know.'
     click_button 'Create Question'
     page.current_path.should =~ /questions\/(\d)+/
     fill_in 'answer-text', :with => 'chips ahoy'
     click_button 'Post Answer'
     # no assertion?
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
end

