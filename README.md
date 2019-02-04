[![Maintainability](https://api.codeclimate.com/v1/badges/fe9b48d7b87315f38be9/maintainability)](https://codeclimate.com/github/jcraigk/phishin/maintainability)

![Phish.in' Logo](https://i.imgur.com/Zmj586L.jpg)

Phish.in' is a web-based archive containing legal live audio recordings of the improvisational rock band Phish.

Ruby on Rails and PostgreSQL are used on the server side.  There's a web frontend (http://phish.in) and a public REST-ish API (http://phish.in/api-docs).  The web frontend utilizes soundmanager2 as the audio playback engine.

All audio is currently in MP3 format; more formats may be made available at a later time.  Files are currently served directly from the web server and cached via CloudFlare CDN.

Join the [Discord](https://discord.gg/KZWFsNN) to discuss curation and development.

## Developer setup

1. Install [Docker](https://www.docker.com/).

2. From the repo folder, build and start the containers.

```bash
make build
make start
```

3. Download the [data/audio seed file](https://www.dropbox.com/s/o1d40ik3crme0vj/phishin_for_devs.20190129.zip?dl=1) and unzip it.  This file contains a full set of data with user and other sensitive information purged.  It also includes all mp3 audio files for the last Baker's Dozen show (2017-08-06).

```bash
# Copy the SQL dump into PG container and run it
docker cp /path/to/phishin_for_devs.sql phishin_pg_1:/docker-entrypoint-initdb.d/dump.sql
docker exec -u postgres phishin_pg_1 psql phishin postgres -f docker-entrypoint-initdb.d/dump.sql
```

5. Place the `tracks` folder on your local drive.  If you run Rails inside Docker (recommended as a starting point), set its location in `docker-compose.yml` (default is `/j/app_content/phishin`). If you run Rails outside Docker, set its location as `APP_CONTENT_PATH` in `.env` and symlink it to your public folder: `ln -s <path to files>/audio_files public/audio`.

Open your browser and direct it to `http://localhost/2017-08-06`.  You should be able to play the full show through the browser.

## Testing

First, create the test db:

```bash
rails db:create RAILS_ENV=test
rails db:schema:load RAILS_ENV=test
```

Then run the specs:

```bash
rspec
```

## Importing Audio

To import a new show or replace an existing one, name the MP3s according to the import format (`I 01 Harry Hood.mp3`) and place them in a folder named by date (`2018-08-12`).  Place this folder in `/content/import` (as seen from the app container) and run the following command from within the container (`docker-compose exec app bash`):

```bash
rails shows:import
```

Use the interactive CLI to execute the import, then go to the `rails console`:

```ruby
Show.unscoped.last.update(
  tour: Tour.find("<tour id>"),
  taper_notes: "<paste taper notes>",
  published: true
)
```

Go to `https://phish.in/<date>` to verify the import.

## Maintenance

You can create a new user via the Rails console (`rails c`).  See [Devise documentation](https://github.com/plataformatec/devise) for details on the authentication system.

## Contributions

Forked from [StreamPhish](https://github.com/jeffplang/streamphish/) by Jeff Lang.

Layout and graphic design by Mark Craig.

Logo design by Justin Craig-Kuhn.
