require 'sinatra'
Sinatra::Application.environment = :test


require './environment'
require './snacks'
disable :run

require 'rack/test'

require 'rspec/autorun'
require 'rspec/mocks'
require 'capybara'
require 'capybara/dsl'


if ENV['SAUCE_URL']
  Capybara.run_server = false
  Capybara.app_host = ENV['SAUCE_URL']
else
  Capybara.app = Sinatra::Application
end

def clean_db
  DB.from(:tags, :articles, :articles_tags, :votes, :comments, :users).truncate
end
