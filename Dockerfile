FROM ruby:2.5.1

ARG DATABASE_URL
ENV DATABASE_URL=${DATABASE_URL}

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# Bundle install, copy app
WORKDIR .
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

# Symlink audio file storage to Rails public folder
RUN ln -s /content/tracks/audio_files ./public/audio

EXPOSE 3000
