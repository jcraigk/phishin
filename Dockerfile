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
      imagemagick \
      libmagickwand-dev \
      libjpeg-dev \
    && apt-get clean

# Update and install necessary packages for timg and other dependencies
RUN apt-get update && apt-get install -y \
    cmake git g++ pkg-config \
    libgraphicsmagick++-dev libturbojpeg-dev libexif-dev libswscale-dev libdeflate-dev librsvg2-dev libcairo-dev \
    libsixel-dev \
    libavcodec-dev libavformat-dev \
    libavdevice-dev \
    libopenslide-dev \
    libpoppler-glib-dev \
    pandoc \
    --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Build and install timg
RUN git clone https://github.com/hzeller/timg.git && \
    cd timg && \
    mkdir build && \
    cd build && \
    cmake ../ -DWITH_OPENSLIDE_SUPPORT=On && \
    make && \
    make install

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

# Expose Shrine attachments as public cacheable URLs
RUN ln -sf /content/tracks/audio_files ./public/audio

# Expose ActiveStorage attachments as public cacheable URLs
RUN ln -sf /content/active_storage ./public/attachments

EXPOSE 3000
CMD bundle exec puma -b tcp://0.0.0.0:3000
