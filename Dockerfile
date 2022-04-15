FROM ruby:3.1.2-slim

ARG APP_NAME=phishin

ENV APP_NAME=${APP_NAME} \
    INSTALL_PATH=/${APP_NAME} \
    IN_DOCKER=true

RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      chromium-driver \
      curl \
      ffmpeg \
      git \
      libpq-dev \
      libsndfile-dev \
      memcached \
      nodejs \
      shared-mime-info \
    && apt-get clean

# Bundle install, copy app
WORKDIR $INSTALL_PATH

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install
COPY . .

# Symlink audio files to Rails public folder
RUN ln -sf /content/tracks/audio_files ./public/audio

EXPOSE 3000
CMD bundle exec puma -b tcp://0.0.0.0:3000
