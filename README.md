Phish.in'
---------

Phish.in' is a web-based archive containing legal live audio recordings of the Rock band Phish.

Ruby on Rails and PostgreSQL are used on the server side.  There's a web frontend (http://phish.in) and a public REST-ish API (http://phish.in/api-docs).  The web frontend utilizes soundmanager2 as the audio playback engine.

All audio is currently in MP3 format.  More formats may be made available at a later time.

## Developer setup

1. Install [Docker](https://www.docker.com/).

2. From the repo folder, build and start the containers.

```bash
make build
make start
```

3. Download the [data/audio seed file](https://www.dropbox.com/s/mxkevdsz4m40ji6/phishin_for_devs.zip?dl=1) and unzip it.  This file contains a full set of data from Nov 2017 with user data purged.  It also includes all mp3 audio files for the last Baker's Dozen show (2017-08-06).

```bash
# Copy the SQL dump into PG container and run it
docker cp /path/to/phishin_for_devs.sql phishin_pg_1:/docker-entrypoint-initdb.d/dump.sql
docker exec -u postgres phishin_pg_1 psql phishin postgres -f docker-entrypoint-initdb.d/dump.sql
```

4. Copy the `config/database.yml.example` to `config/database.yml`.

5. Place the `tracks` folder on your local drive and set its location in `docker-compose.yml` (default is `/private/var/app_content/phishin`).

Open your browser and direct it to `http://localhost/2017-08-06`.  You should be able to play the full show through the browser.

## Maintenance

You can create a new user via the Rails console (`rails c`).  See [Devise documentation](https://github.com/plataformatec/devise) for details.  Note that you must `confirm!` the user after creating it.

You can use [Adminer](https://www.adminer.org/) to interact with Postgres using a GUI.  Visit `http://localhost:81` and select `PostgreSQL` in the System dropdown menu.  Server is `pg`, username/pass are both `postgres`, db name is `phishin`.
