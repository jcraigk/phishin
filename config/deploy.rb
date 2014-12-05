set :application,           'phishin'
set :repo_url,              'git@github.com:jcraigk/phishin.git'
set :deploy_to,             '/var/www/html.phish.in'
set :audio_path,            '/var/www/app_content/phishin/tracks/audio_files'


desc 'Create symlink to database.yml'
task :link_database_yml do
  sh "ln -nfs #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
end

desc 'Create symlink to audio content folder'
task :link_audio do
  sh "ln -s #{audio_path} #{release_path}/public/audio"
end

desc 'Restart application'
task :restart do
  on roles(:app), in: :sequence, wait: 5 do
    sh "touch #{deploy_to}/current/tmp/restart.txt"
  end
end

after 'deploy:updated', :link_database_yml
after 'deploy', :link_audio
after 'deploy', :restart