require 'rubygems'
require 'json'
require 'yaml'
require 'sinatra'
require 'sequel'
require 'omniauth'
require 'omniauth-google-apps'
require 'american_date' # will monkeypatch dates
require 'time-lord'

environment = Sinatra::Application.environment

puts "Booting in test mode..." if environment == :test

DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres://localhost/snacks_#{environment}")
DB.sql_log_level = :debug
Sequel::Model.db = DB
Sequel::Model.plugin :json_serializer
Sequel.datetime_class = DateTime

class SnacksConfig
  def self.allow_anonymous_readers
    !!ENV['ALLOW_ANONYMOUS_READERS']
  end
  
  def self.google_apps_domain
    ENV['GOOGLE_APPS_DOMAIN'] || 'gmail.com'
  end
  
  def self.xss_token
    ENV['XSS_TOKEN'] || 'default_xss_token_dont_use_me'
  end
end