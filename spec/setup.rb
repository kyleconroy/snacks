require 'sinatra'
Sinatra::Application.environment = :test

require './environment'
require './snacks'
disable :run

require 'rack/test'

require 'rspec/autorun'
require 'capybara'
require 'capybara/dsl'

Capybara.app = Sinatra::Application


def clean_db
  DB.from(:tags, :articles, :articles_tags, :votes, :comments).truncate
end