.PHONY : build clean services spec start stop up

all : build up

build :
	docker-compose build

clean :
	docker-compose down
	docker-compose rm
	docker image prune
	docker volume prune

services :
	docker-compose up -d pg

spec :
	RAILS_ENV=test docker-compose run --rm app bundle exec rspec $(file)

start : services
	docker-compose up -d

stop:
	docker-compose stop

up : services
	docker-compose up

restart :
	docker-compose stop
	docker-compose up -d
