![Phish.in Logo](app/javascript/images/logo-full.png)

Phish.in is an open source archive of live Phish audience recordings.

Ruby on Rails and Grape API wrap a PostgreSQL database on the backend. There's a [web frontend](https://phish.in) written in React for browsing and playing audio content as well as a [JSON API](https://petstore.swagger.io/?url=https%3A%2F%2Fphish.in/api/v2/swagger_doc) for accessing content programmatically.

All audio is provided in MP3 format. More formats and sources may be made available at a later time. Assets including audio MP3s, waveform PNGs, and album art JPEGs are served directly from the web server and cached via CloudFlare CDN.

Join the [Discord](https://discord.gg/KZWFsNN) to discuss content and development or install the [Discord Bot](https://github.com/jcraigk/phishin-discord) to query setlists and play music in voice channels.


## Developer Setup

1. Install [Docker](https://www.docker.com/)

2. Clone the repo to your local machine
3. Create a `.env` file at the root of the repository
4. Run `mise run services`

5. Download the [Development SQL File](https://www.dropbox.com/scl/fi/6zv4bzxxcjgv3ouv8d3ek/phishin-dev.sql?rlkey=4trafp2vxcgc1iuuq36yhl9gc) and import it:

```bash
# Copy SQL dump into PG container and run it
$ docker cp /path/to/phishin-dev.sql phishin-pg-1:/docker-entrypoint-initdb.d/data.sql
$ docker exec -u postgres phishin-pg-1 createdb phishin_development
$ docker exec -u postgres phishin-pg-1 psql -d phishin_development -f docker-entrypoint-initdb.d/data.sql
```

4. To present production content locally during development, set `PRODUCTION_CONTENT=true` in your local `.env` file.

5. If you want to run the Postgres database in Docker and develop the app natively (recommended), you can spin it up like this:

Install [mise](https://mise.jdx.dev/) for ruby version management (recommended):
```bash
$ brew install mise
$ mise install
```

Install dependencies:
```bash
$ brew install overmind # process manager (requires tmux)
$ gem install bundler
$ bundle install
$ yarn install
```

Run the app:
```bash
$ mise run dev
```

If you are on a Mac ARM and the `ruby-audio` gem fails to install, see the Troubleshooting section below.

Alternatively, if you prefer to develop completely in Docker, build and start the containers like this:

```bash
$ mise run up
```

## Testing

To run the specs in Docker:

```bash
$ mise run spec
```

To run the specs natively:

```bash
$ mise run services
$ bundle exec rails db:setup RAILS_ENV=test
$ bundle exec rspec
```

## Importing Content

The content import process uses the [Phish.net API](https://docs.phish.net/) for setlists. You must first obtain an API key from them and assign it to the environment variable `PNET_API_KEY` in `.env`.

If running the Rails app natively, you may need to install `ffmpeg`.

To import a new show or replace an existing one, name the MP3s according to the import format (`I 01 Harry Hood.mp3`) and place them in a folder named by date (`2018-08-12`). Place this folder in `./content/import` and run the following command (`mise run bash` first if you use Docker):

```bash
bundle exec rails shows:import
```

Use the interactive CLI to finish the import process then set `PRODUCTION_CONTENT=false`, restart the server, and visit `http://localhost:3000/<date>` to verify the import.


## Troubleshooting (Appendix)

### Postgres Connection Issues
- If you get a `NoDatabaseError` or `connection to server at "localhost" failed`, make sure:
  - No other Postgres server is running on your Mac (use `brew services list`, `ps aux | grep postgres`, or `lsof -i :5432`).
  - Stop any native Postgres with `brew services stop postgresql` or by quitting Postgres.app.
  - After stopping, restart your Docker Postgres:
    ```sh
    mise run services
    ```
  - You should see your database with:
    ```sh
    psql -h localhost -U postgres -l
    ```
  - If you do not see `phishin_development` in the list, re-import your SQL dump as described above.

### Webpack Dev Server Port Conflict
- If you see an error like `EADDRINUSE: address already in use 127.0.0.1:3035`, run:
  ```sh
  lsof -i :3035
  ```
  and kill any stray `node` processes:
  ```sh
  kill -9 <PID>
  ```

### Mac ARM: ruby-audio Gem Installation
- If you are on a Mac ARM and the `ruby-audio` gem fails to install, try the following:
  ```sh
  brew install libsndfile
  gem install ruby-audio -- --with-sndfile-dir=/opt/homebrew/opt/libsndfile
  ```

## Contributions

Forked with permission in 2012 from [StreamPhish](https://github.com/jeffplang/streamphish/) by Jeff Lang.

Software and content maintained by [Justin Craig-Kuhn](https://github.com/jcraigk).
