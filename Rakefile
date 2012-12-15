require "sequel"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = FileList['spec/*_spec.rb']
end

task :default => :spec

namespace :test do
  task :prepare do
    Sequel.extension :migration
    db = Sequel.connect('postgres://localhost/snacks_test')
    Sequel::Migrator.run(db, "migrations", :target => 0)
    Sequel::Migrator.run(db, "migrations")
    puts "<= test:prepare executed"
  end
end

namespace :db do
  namespace :migrate do
    Sequel.extension :migration
    DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/snacks_development')

    desc "Perform migration reset (full erase and migration up)"
    task :reset do
      Sequel::Migrator.run(DB, "migrations", :target => 0)
      Sequel::Migrator.run(DB, "migrations")
      puts "<= sq:migrate:reset executed"
    end

    desc "Perform migration up to latest migration available"
    task :up do
      Sequel::Migrator.run(DB, "migrations")
      puts "<= sq:migrate:up executed"
    end
  end
end
