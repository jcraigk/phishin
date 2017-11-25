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
You can always refer to the [Rails Guides](http://guides.rubyonrails.org/) if you want detailed information about how to run and develop Rails projects.  Note that Phish.in is currently running on an outdated version of Rails, v3.2.  An upgrade is planned in the future.

To setup a fresh development environment, do the following:

Clone this git repo into a local folder.

Navigate to the project's path on your machine.  If you do not have the correct version of Ruby available, rvm will prompt you to install it.

Run `bundle install` to install all gem dependencies.

You can create a fresh empty development database by running `bundle exec rake db:create` and you can create a fresh test database by running `RAILS_ENV=test bundle exec rake db:create`.

Copy the `config/database.yml.example` to `config/database.yml` and enter the appropriate configuration for your local PostgreSQL database.

Now you should be able to launch the app locally by running `rails s`.  Open your browser and direct it to `http://localhost:3000`, which should serve the root path of the app.

You can invoke a local Rails Console by running `rails c`.

**TODO:** Provide seed data and/or a skeleton database (excluding or obfuscating user details).

