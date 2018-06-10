# frozen_string_literal: true
set :application, 'phishin'
set :repo_url, 'git@github.com:jcraigk/phishin.git'

desc 'Create symlink to audio content folder'
task :link_audio do
  on roles(:app) do
    execute "ln -s #{fetch(:audio_path)} #{release_path}/public/audio"
  end
end

desc 'Restart Passenger'
task :restart_passenger do
  on roles(:app) do
    execute "touch #{release_path}/tmp/restart.txt"
  end
end
