FROM ruby:3.3.3-slim-bullseye

ARG APP_NAME=phishin

ENV APP_NAME=${APP_NAME} \
    INSTALL_PATH=/${APP_NAME} \
    IN_DOCKER=true

# Install system dependencies
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
      shared-mime-info \
    && apt-get clean

# Install Node and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs
RUN npm install -g yarn

WORKDIR $INSTALL_PATH

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

COPY package.json yarn.lock ./
RUN yarn install

COPY . .

# Expose audio files thru Rails public folder
RUN ln -sf /content/tracks/audio_files ./public/audio

EXPOSE 3000
CMD bundle exec puma -b tcp://0.0.0.0:3000
