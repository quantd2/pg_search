# frozen_string_literal: true

case RUBY_PLATFORM
when "java"
  require "activerecord-jdbc-adapter"
  ERROR_CLASS = ActiveRecord::JDBCError
else
  require "pg"
  ERROR_CLASS = PG::Error
end

begin
  ActiveRecord::Base.establish_connection(adapter: 'postgresql',
                                          database: 'pg_search_test',
                                          username: (ENV["TRAVIS"] ? "postgres" : ENV["USER"]),
                                          min_messages: 'warning')
  connection = ActiveRecord::Base.connection
  connection.execute("SELECT 1")
rescue ERROR_CLASS, ActiveRecord::NoDatabaseError => exception
  at_exit do
    puts "-" * 80
    puts "Unable to connect to database.  Please run:"
    puts
    puts "    createdb pg_search_test"
    puts "-" * 80
  end
  raise exception
end

if ENV["LOGGER"]
  require "logger"
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end

def install_extension(name)
  connection = ActiveRecord::Base.connection
  extension = connection.execute "SELECT * FROM pg_catalog.pg_extension WHERE extname = '#{name}';"
  return unless extension.none?

  connection.execute "CREATE EXTENSION #{name};"
rescue StandardError => exception
  at_exit do
    puts "-" * 80
    puts "Please install the #{name} extension"
    puts "-" * 80
  end
  raise exception
end

def install_extension_if_missing(name, query, expected_result)
  result = ActiveRecord::Base.connection.select_value(query)
  raise "Unexpected output for #{query}: #{result.inspect}" unless result.casecmp(expected_result).zero?
rescue StandardError
  install_extension(name)
end

install_extension_if_missing("pg_trgm", "SELECT 'abcdef' % 'cdef'", "t")
install_extension_if_missing("unaccent", "SELECT unaccent('foo')", "foo")
install_extension_if_missing("fuzzystrmatch", "SELECT dmetaphone('foo')", "f")

def load_sql(filename)
  connection = ActiveRecord::Base.connection
  file_contents = File.read(File.join(File.dirname(__FILE__), '..', '..', 'sql', filename))
  connection.execute(file_contents)
end

load_sql("dmetaphone.sql")
