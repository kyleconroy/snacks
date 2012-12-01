require_relative './setup'

Capybara.default_driver = :selenium

describe 'browser tests with javascript' do
  include Capybara::DSL

  before :each do
    clean_db
    User.create(:uid => 'FAKE_TEST_UID', :name => 'The Test User',  :created_at => Time.now)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_apps] = OmniAuth::AuthHash.new({
        :provider => 'google_apps',
        :uid => 'FAKE_TEST_UID',
      })
    visit '/logout' # get new cookie
  end
  
  it "can edit an existing question" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => 'Ice cream'
    click_button 'Create Question'
    click_link "Edit"
    fill_in 'text', :with => 'Jelly Donut'

    fill_in 'tag_input', :with => 'pastries'
    find('.tag-input').native.send_keys(:return)
    click_button 'Save'
    page.current_path.should =~ /questions\/(\d+)$/
    page.should have_content 'Jelly Donut'
    page.should have_content 'pastries'
  end
  
  it "can create a new question with tags" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => 'Ice cream'
    fill_in 'tag_input', :with => 'pastries'
    find('.tag-input').native.send_keys(:return)
    click_button 'Create Question'
    page.current_path.should =~ /questions\/(\d+)$/
    page.should have_content 'pastries'
  end
  
  it "persists the state of your tag edits when the question validation fails" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => 'Ice cream'
    fill_in 'tag_input', :with => 'pastries'
    find('.tag-input').native.send_keys(:return)
    click_button 'Create Question'
    
    page.current_path.should =~ /questions\/(\d+)$/
    click_link 'Edit'
    fill_in 'title', :with => 'Invd'
    page.should have_css('span[data-name="pastries"]')
    within("span[data-name='pastries']") { find('a.delete-tag').click }
    find("input[name='title']").value.should == 'Invd'
    fill_in 'tag_input', :with => 'donuts'
    find('.tag-input').native.send_keys(:return)
    click_button "Save"
    page.should have_css("span[data-name='donuts']")
    page.should_not have_css("span[data-name='pastries']")
    fill_in 'tag_input', :with => 'pastries'
    find('.tag-input').native.send_keys(:return)
    click_button "Save"
    page.should have_css("span[data-name='donuts']")
    page.all("span[data-name='pastries']").length.should == 1
  end
  
  it "can upvote an question only once, and then undo the upvote" do
    visit '/'
    click_link 'Add Question'
    fill_in 'title', :with => "What is the best snack?"
    fill_in 'text', :with => 'Ice cream'
    click_button 'Create Question'
    within '#question' do
      expect { find('.upvote').click }.to change{ Vote.count }.by(1)
      expect { find('.downvote').click }.to change{ Vote.count }.by(0)
      expect { find('.upvote').click }.to change{ Vote.count }.by(-1)
      expect { find('.downvote').click }.to change{ Vote.count }.by(1)
      expect { find('.upvote').click }.to change{ Vote.count }.by(0)
      expect { find('.downvote').click }.to change{ Vote.count }.by(-1)
    end
    
    fill_in 'answer-text', :with => 'chips ahoy'
    click_button 'Post Answer'
    
    within '.answer' do
      expect { find('.upvote').click }.to change{ Vote.count }.by(1)
      expect { find('.downvote').click }.to change{ Vote.count }.by(0)
      expect { find('.upvote').click }.to change{ Vote.count }.by(-1)
      expect { find('.downvote').click }.to change{ Vote.count }.by(1)
      expect { find('.upvote').click }.to change{ Vote.count }.by(0)
      expect { find('.downvote').click }.to change{ Vote.count }.by(-1)
    end
  end
end