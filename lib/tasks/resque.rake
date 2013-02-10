require "resque/tasks"

task "resque:setup" => :environment do
  #ENV['QUEUE'] = '*'
  # Fix for Postgres prepared statement issues
  Resque.before_fork = Proc.new { ActiveRecord::Base.establish_connection }
end