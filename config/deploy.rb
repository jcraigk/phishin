set :application,   'phishin'
set :repo_url,      'git@github.com:jcraigk/phishin.git'

namespace :deploy do
 
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  desc 'Create symlink to audio content folder'
  task :link_audio do
    on roles(:app) do
      execute "ln -s #{fetch(:audio_path)} #{release_path}/public/audio"
    end
  end

  after :publishing, :link_audio
  after :publishing, :restart
end