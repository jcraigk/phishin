require 'bundler/capistrano'
load 'deploy/assets'

#########################################################

set :application,           "phishin"
set :user,                  "jcraigk"
set :scm,                   :git
set :repository,            "git@github.com:jcraigk/phishin.git"
set :deploy_to,             "/var/www/html.phish.in/"
set :production_server,     "phish.in"
set :staging_server,        "phish.in"
set :use_sudo,              false
set :audio_path,            "/var/www/app_content/phishin/tracks/audio_files/"


before "deploy",            "deploy:check_revision"

after "deploy",             "deploy:link_database_yml"
after "deploy",             "deploy:migrate"
after "deploy",             "deploy:link_audio"
after "deploy",             "deploy:restart"
after "deploy",             "deploy:cleanup"

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
  task :restart do
    run "#{try_sudo} mkdir -p #{deploy_to}current/tmp/"
    run "#{try_sudo} touch #{deploy_to}current/tmp/restart.txt"
  end
  after "deploy:restart" do
    run "rm -rf #{release_path}.git"
  end
  task :finalize_update do
    run "chmod -R g+w #{release_path}"
  end
  task :link_audio do
    run "ln -s #{audio_path} #{release_path}/public/audio"
  end

  # Make sure local git is in sync with remote
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  
  task :link_database_yml, roles: :app do
    run "ln -nfs #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
  end
  
end
