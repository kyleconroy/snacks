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
puts "the database url is #{ENV['DATABASE_URL']}"
DB = Sequel.connect(ENV['DATABASE_URL'] || "postgres://127.0.0.1/snacks_#{environment}")
DB.sql_log_level = :debug
# DB.logger = Logger.new($stdout)
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