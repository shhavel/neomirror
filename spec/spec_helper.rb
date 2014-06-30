require "neomirror"
require "active_record"
require "database_cleaner"
require "factory_girl"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ENV['NEO_URL'] ||= "http://127.0.0.1:7474"
Neomirror.connection = Neography::Rest.new(ENV['NEO_URL'])

ActiveRecord::Base.connection.execute('CREATE TABLE premises ("id" INTEGER PRIMARY KEY NOT NULL)')
ActiveRecord::Base.connection.execute('CREATE TABLE groups ("id" INTEGER PRIMARY KEY NOT NULL)')
ActiveRecord::Base.connection.execute('CREATE TABLE users ("id" INTEGER PRIMARY KEY NOT NULL, "name" varchar(255) NOT NULL)')
ActiveRecord::Base.connection.execute('CREATE TABLE memberships ("id" INTEGER PRIMARY KEY NOT NULL, "premises_id" INTEGER DEFAULT NULL, "group_id" INTEGER DEFAULT NULL)')
ActiveRecord::Base.connection.execute('CREATE TABLE staff ("id" INTEGER PRIMARY KEY NOT NULL, "user_id" INTEGER DEFAULT NULL, "premises_id" INTEGER DEFAULT NULL, "group_id" INTEGER DEFAULT NULL, "roles" TEXT)')

FactoryGirl.find_definitions

Dir["./spec/support/**/*.rb"].sort.each {|f| require f}

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
    Neomirror.neo.execute_query("START n=node(*) OPTIONAL MATCH n-[r]-() DELETE n,r")
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
