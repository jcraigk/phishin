Phish.in'
---------

Phish.in' is a web-based archive containing legal live audio recordings of the musical group Phish.

Ruby on Rails and PostgreSQL are used on the server side.  There's a web frontend (http://phish.in) and a public JSON API (http://phish.in/api-docs).  The web frontend utilizes soundmanager2 as the audio playback engine.

All audio is currently in MP3 format.  More formats may be made available at a later time.

## Developer setup

You will need the following on your machine in order to develop against this project:
 - Ruby programming language
 - PostgreSQL relational database

### Installing Ruby
[rvm](https://rvm.io/) is recommended for Ruby version management.  Once rvm is installed, if you navigate into a ruby project's folder, rvm will automatically detect the Ruby version via the `Gemfile` and invoke the appropriate version of Ruby.

### Installing PostgreSQL
You can download an installer from the [PostgreSQL website](https://www.postgresql.org/download/) or use [Docker](https://www.docker.com/) to virtualize the service.  Version 10 is recommended.

### Rails Setup
You may refer to the [Rails Guides](http://guides.rubyonrails.org/) if you want detailed information about how to run and develop Rails projects.  Note that Phish.in is currently running Rails v3.2, which is outdated.  An upgrade is planned in the future.

To setup a fresh development environment:

1. Clone this git repo into a local folder.

2. Navigate to the project's path on your machine.  If you do not have the correct version of Ruby available, rvm will prompt you to install it.

3. Run `bundle install` to install all gem dependencies.

*Note: 'taglib-ruby' requires the taglib C++ library `brew install taglib`

4. Download the [data/audio seed file](https://www.dropbox.com/s/mxkevdsz4m40ji6/phishin_for_devs.zip?dl=1) and unzip it.  This file contains a full set of data from Nov 2017 minus all users.  It also includes all mp3 audio files for the last Baker's Dozen show 2017-08-06.

5. Place the `tracks` folder on your local hard drive and set its location using the `APP_CONTENT_PATH` constant in the file `initializers/app_constants.rb`.

6. Create a symlink from `tracks` folder to `public/audio`:
`ln -s ~/Downloads/phishin_for_devs/tracks public/audio`

7. Copy the `config/database.yml.example` to `config/database.yml` and enter the appropriate configuration for your local PostgreSQL database.

8. Create a fresh empty database by running `bundle exec rake db:create`.

9. Import the seed data by running `psql phishin_dev < phishin_for_devs.sql`.

10. Launch the app locally by running `rails s`.

11. Open your browser and direct it to `http://localhost:3000/2017-08-06`.  You should be able to play the full show.

12. Create a new user via the Rails console (`rails c`).  See [Devise documentation](https://github.com/plataformatec/devise) for details.  Note that you must `confirm!` the user after creating it.
