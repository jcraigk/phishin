[![Build Status](https://app.travis-ci.com/jcraigk/phishin.svg?branch=main)](https://travis-ci.org/jcraigk/phishin)

![Phish.in Logo](https://i.imgur.com/Zmj586L.jpg)

Phish.in is an open source archive of live Phish audience recordings.

Ruby on Rails and PostgreSQL are used on the server side. There's a web frontend (https://phish.in) and a public REST-ish API (https://phish.in/api-docs). The web frontend uses soundmanager2 as the audio playback engine.

All audio is provided in MP3 format; more formats and sources may be made available at a later time. Files are served directly from the web server and cached via CloudFlare CDN.

Join the [Discord](https://discord.gg/KZWFsNN) to discuss content and development.


## Developer Setup

1. Install [Docker](https://www.docker.com/)

2. Clone the repo to your local machine

4. Download the [Fixtures Pack](https://www.dropbox.com/scl/fi/s822to1wv8y7ra3l3pao1/PhishinDevFixtures.zip?rlkey=t1us9qzosl941hak2msujcfuy&dl=0) and unzip it. This file contains a full database export minus users and API keys. It also includes MP3 audio and PNG waveform attachments for the last Baker's Dozen show, which should be browsable and playable via `localhost:3000/2017-08-06` once the local server is running. Additionally it includes MP3s/notes for 2018-12-28 for testing the `rails shows:import` task.

```bash
# Copy SQL dump into PG container and run it
docker cp /path/to/phishin_for_devs.sql phishin_pg_1:/docker-entrypoint-initdb.d/dump.sql
docker exec -u postgres phishin_pg_1 psql phishin postgres -f docker-entrypoint-initdb.d/dump.sql
```

5. Create a folder named `content` in the local project folder. Place the `tracks` and `import` folders from the Fixtures Pack inside. Symlink the `tracks/audio_files` folder as `audio` in your public folder: `ln -s ./content/tracks/audio_files public/audio`. If you run Rails outside Docker, set `APP_CONTENT_PATH` in `.env` as the absolute path to your `content` folder.

6. If you want to run the Postgres database in Docker and develop the app natively (recommended), you can spin it up like this:

```bash
make services
bundle
bundle exec rails s
```

If you are on a Mac M1 and the `ruby-audio` gem fails to install, try the following:

```
brew install libsndfile
gem install ruby-audio -- --with-sndfile-dir=/opt/homebrew/opt/libsndfile
```

Alternatively, if you prefer to develop completely in Docker, build and start the containers like this:

```bash
make up
```

7. Open your browser and go to `http://localhost:3000/2017-08-06`. You should be able to view and play the full show.


## Testing

To run the specs in Docker:

```bash
make spec
```

To run the specs natively:

```bash
make services
bundle exec rails db:setup RAILS_ENV=test
bundle exec rspec
```


## Importing Content

The content import process uses the [Phish.net API](https://docs.phish.net/) for setlists. You must first obtain an API key from them and assign it to the environment variable `PNET_API_KEY` in `.env`.

If running the Rails app natively, you may need to install `ffmpeg`.

To import a new show or replace an existing one, name the MP3s according to the import format (`I 01 Harry Hood.mp3`) and place them in a folder named by date (`2018-08-12`). Place this folder in `./content/import` and run the following command (`make bash` first if you use Docker):

```bash
bundle exec rails shows:import
```

Use the interactive CLI to finish the import process then go to `http://localhost:3000/<date>` to verify the import.


## Maintenance

You can create a new user via the Rails console (`bundle exec rails c`). See [Devise documentation](https://github.com/plataformatec/devise) for details on the authentication system.


## Contributions

Forked from [StreamPhish](https://github.com/jeffplang/streamphish/) by Jeff Lang.

Layout and graphic design by Mark Craig.

Logo design by Justin Craig-Kuhn.
