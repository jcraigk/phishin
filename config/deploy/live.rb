server '66.33.207.45', user: 'jcraigk', roles: %w{web app db}

set :rails_env,     :production
set :deploy_to,     '/var/www/apps/phishin'
set :audio_path,    '/var/www/app_content/phishin/tracks/audio_files'
set :linked_files,  %w(config/database.yml)
set :tmp_dir,       '/home/jcraigk/tmp'