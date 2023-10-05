# Stage 1: Node.js
FROM node:14 AS node-builder

ARG APP_NAME=phishin
ENV INSTALL_PATH=/${APP_NAME}

WORKDIR $INSTALL_PATH

# Copy over your package.json, yarn.lock, and any other necessary files for asset compilation
COPY package.json yarn.lock ./
RUN yarn install

# If you have other frontend assets that need processing, copy them here
COPY . ./
# Then run whatever build scripts you have, e.g. webpack, etc.
# RUN yarn run build

# Stage 2: Ruby
FROM ruby:3.2.2-slim

# Environment setup
ARG APP_NAME=phishin
ENV APP_NAME=${APP_NAME} \
    INSTALL_PATH=/${APP_NAME} \
    IN_DOCKER=true

WORKDIR $INSTALL_PATH

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
    && apt-get clean

# Install Gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

# Copy over the app code and the precompiled assets from the node-builder stage
COPY --from=node-builder $INSTALL_PATH $INSTALL_PATH

# Expose audio files thru Rails public folder
RUN ln -sf /content/tracks/audio_files ./public/audio

EXPOSE 3000
CMD bundle exec puma -b tcp://0.0.0.0:3000
