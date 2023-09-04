.PHONY : build clean services spec start stop up

all : build up

build :
	docker-compose build

bash :
	RAILS_ENV=test docker-compose run --rm app bash

clean :
	docker-compose down --remove-orphans
	docker-compose rm
	docker image prune
	docker volume prune

cleanforce:
	docker-compose down -v
	docker image prune -af
	docker volume prune -f

services :
	docker-compose up -d pg

spec : services
	docker-compose run --rm app bundle exec rspec $(file)

start : services
	docker-compose up -d

stop:
	docker-compose stop

up : services
	docker-compose up

restart :
	docker-compose stop
	docker-compose up -d
