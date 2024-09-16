** React TODO
 * Form on map should be above the map on mobile (and other sidebars similar?)
 * https://jcktest.ngrok.io/songs/46-days - doesn't need track title, needs venue name, etc (different Tracks component probably). also needs to link to the show and highlight the track, not just play the track.
 * Logging in should retain the path where you clicked login from
 * style the feedback messages - should we use bulma styles or no?
 * Do we need all the keys in the components? look for other excess/DRYness
 * Add a spinner using react-spinners - will require passing loading state from components
 * Put mobile titles in navbar
 * Opengraph (helmet context)
 * track context dropdowns
    * share from timestamp
 * put play random show button on empty playlist page
 * remove data-theme="light" (and maybe bulma entirely)
 * tracks displayed in non-show contexts should have their dates linked to show via button so you can still play the current page as a playlist
 * ErrorPage should handle status codes (Not Found especially)
 * make sure we re-hydrate any pages that have tracks on them when doing SSR (to highlight likes)
 * If you play a show and navigate to a new show, does it take over the playlist?

 * anywhere we can put lyrical excerpts?
 * disable swetrix - or sign up
 * Add CSRF to POSTs on API
 * Can we use as_json to clean up request specs?
 * Caching on SSR (Rails.cache.fetch in layouts/application) (https://github.com/shakacode/react_on_rails/wiki)
 * Disable email account creation - allow oauth login through api?
 * Prerender caching? Would only benefit logged out users since we'd need to rehydrate on load for any pages that showed liked items

[![Build Status](https://app.travis-ci.com/jcraigk/phishin.svg?branch=main)](https://travis-ci.org/jcraigk/phishin)

![Phish.in Logo](https://i.imgur.com/Zmj586L.jpg)

**Phish.in** is an open source archive of live Phish audience recordings.

**Ruby on Rails** and **PostgreSQL** are used on the backend. There's a [web frontend](https://phish.in) for browsing and playing audio content as well as a [public API](https://phish.in/api-docs) for accessing content programmatically.

All audio is provided in MP3 format; more formats and sources may be made available at a later time. Files are served directly from the web server and cached via CloudFlare CDN.

Join the [Discord](https://discord.gg/KZWFsNN) to discuss content and development.


## Developer Setup

1. Install [Docker](https://www.docker.com/)

2. Clone the repo to your local machine

4. Download the [Fixtures Pack](https://www.dropbox.com/scl/fi/ysnbbsbpylm0ny9dygjbc/PhishinDevFixtures.zip?rlkey=bj5kuqvyppixe4cmw8sz30twz&st=qzw4hl4v&dl=0) and unzip it. This file contains a full database export (updated May 2024) minus users and API keys. It also includes MP3 audio and PNG waveform attachments for the last Baker's Dozen show, which should be browsable and playable via `localhost:3000/2017-08-06` once the local server is running. Additionally it includes MP3s/notes for 2018-12-28 for testing the `rails shows:import` task.

```bash
# Copy SQL dump into PG container and run it
docker cp /path/to/phishin.sql phishin-pg-1:/docker-entrypoint-initdb.d/dump.sql
docker exec -u postgres phishin-pg-1 psql phishin postgres -f docker-entrypoint-initdb.d/dump.sql
```

5. Create a folder named `content` in the local project folder. Place the `tracks` and `import` folders from the Fixtures Pack inside. Symlink the `tracks/audio_files` folder as `audio` in your public folder: `ln -s ./content/tracks/audio_files public/audio`. If you run Rails outside Docker, set `APP_CONTENT_PATH` in `.env` as the absolute path to your `content` folder.

6. To use audio and waveform images from production while developing locally, set `PRODUCTION_CONTENT=true` in `.env`.

7. If you want to run the Postgres database in Docker and develop the app natively (recommended), you can spin it up like this:

```bash
make services
bundle
bundle exec rails s
```

If you are on a Mac ARM and the `ruby-audio` gem fails to install, try the following:

```
brew install libsndfile
gem install ruby-audio -- --with-sndfile-dir=/opt/homebrew/opt/libsndfile
```

Alternatively, if you prefer to develop completely in Docker, build and start the containers like this:

```bash
make up
```

8. Open your browser and go to `http://localhost:3000/2017-08-06`. You should be able to view and play the full show.


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


## Contributions

Forked with permission in 2012 from [StreamPhish](https://github.com/jeffplang/streamphish/) by Jeff Lang.

Layout and graphic design by Mark Craig.

Software and content maintained by [Justin Craig-Kuhn](https://github.com/jcraigk).
