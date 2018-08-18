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
	docker-compose up -d pg adminer

spec :
	RAILS_ENV=test docker-compose run --rm app rspec

start : services
	docker-compose up -d

stop:
	docker-compose stop

up : services
	docker-compose up
