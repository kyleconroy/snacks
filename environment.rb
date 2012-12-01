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

class Snacks
  @@configuration = nil
  def self.configuration
    return @@configuration if @@configuration
    @@configuration = YAML.load_file('snacks.yml')
    required_keys = ['google_apps_domain', 'xss_token', 'allow_anonymous_readers']
    raise Exception, 'your snacks.yml is not snacky enough' unless (required_keys - configuration.keys).empty?
    @@configuration
  end
end