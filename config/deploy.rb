require 'bundler/capistrano'

#########################################################

set :application,           "phishin"
set :user,                  "jcraigk"
set :scm,                   :git
set :repository,            "git@github.com:jcraigk/phishin.git"
set :deploy_to,             "/var/www/html.phish.in/"
set :production_server,     "phish.in"
set :staging_server,        "phish.in"
set :use_sudo,              false

# Cleanup and migrate
after "deploy",             "deploy:cleanup"
after "deploy",             "deploy:migrate"
after "deploy",             "deploy:assets"

#########################################################

task :live do
  server production_server, :app, :web, :db, :primary => true
  set :server_name, production_server
end

task :staging do
  server staging_server, :web, :app, :db, :primary => true
  set :server_name, staging_server
end

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{deploy_to}/current/tmp/restart.txt"
  end
  after "deploy:restart" do
    run "rm -rf #{release_path}.git"
  end
  task :finalize_update do
    run "chmod -R g+w #{release_path}"
  end

  # Make sure local git is in sync with remote
  task :check_revision, :roles => :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
  
  task :assets do
    run "cd #{current_path} && bundle exec rake assets:precompile RAILS_ENV=#{rails_env}"
  end
  
end
