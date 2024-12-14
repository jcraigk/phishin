![Phish.in Logo](app/javascript/images/logo-full.png)

Phish.in is an open source archive of live Phish audience recordings.

Ruby on Rails and Grape API wrap a PostgreSQL database on the backend. There's a [web frontend](https://phish.in) written in React for browsing and playing audio content as well as a [JSON API](https://petstore.swagger.io/?url=https%3A%2F%2Fphish.in/api/v2/swagger_doc) for accessing content programmatically.

All audio is provided in MP3 format. More formats and sources may be made available at a later time. Assets including audio MP3s, waveform PNGs, and album art JPEGs are served directly from the web server and cached via CloudFlare CDN.

Join the [Discord](https://discord.gg/KZWFsNN) to discuss content and development.


## Developer Setup

1. Install [Docker](https://www.docker.com/)

2. Clone the repo to your local machine

3. Download the [Development SQL File](https://dl.dropboxusercontent.com/scl/fi/6zv4bzxxcjgv3ouv8d3ek/phishin-dev.sql?rlkey=4trafp2vxcgc1iuuq36yhl9gc&st=ch5zi7xy) and import it:

```bash
# Copy SQL dump into PG container and run it
docker cp /path/to/phishin.sql phishin-pg-1:/docker-entrypoint-initdb.d/dump.sql
docker exec -u postgres phishin-pg-1 psql phishin postgres -f docker-entrypoint-initdb.d/dump.sql
```

4. To present production content locally during development, set `PRODUCTION_CONTENT=true` in your local `.env` file.

5. If you want to run the Postgres database in Docker and develop the app natively (recommended), you can spin it up like this:

```bash
make services
make dev
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

Use the interactive CLI to finish the import process then set `PRODUCTION_CONTENT=false`, restart the server, and visit `http://localhost:3000/<date>` to verify the import.


## Contributions

Forked with permission in 2012 from [StreamPhish](https://github.com/jeffplang/streamphish/) by Jeff Lang.

Layout and graphic design by Mark Craig.

Software and content maintained by [Justin Craig-Kuhn](https://github.com/jcraigk).
