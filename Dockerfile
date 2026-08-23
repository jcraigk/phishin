FROM ruby:4.0.4-slim

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
      git \
      libpq-dev \
      libsndfile-dev \
      memcached \
      shared-mime-info \
      imagemagick \
      libmagickwand-dev \
      libjpeg-dev \
      libyaml-dev \
      lame \
    && apt-get clean

# ffmpeg 8.1 rather than Debian's 7.x. The two differ in ways that change
# audio output: 7.x reports a LAME-gapless file's untrimmed duration while its
# own decoder yields the trimmed one, and it leaves ~18ms of encoder padding
# decodable where 8.x trims it. TrackMergeService measures both, so a version
# split between development and production produced different merges from the
# same inputs.
ARG FFMPEG_BUILD=ffmpeg-n8.1-latest-linux64-gpl-8.1
RUN curl -fsSL -o /tmp/ffmpeg.tar.xz \
      "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/${FFMPEG_BUILD}.tar.xz" && \
    tar -xJf /tmp/ffmpeg.tar.xz -C /tmp && \
    install -m 755 /tmp/${FFMPEG_BUILD}/bin/ffmpeg /usr/local/bin/ffmpeg && \
    install -m 755 /tmp/${FFMPEG_BUILD}/bin/ffprobe /usr/local/bin/ffprobe && \
    rm -rf /tmp/ffmpeg.tar.xz /tmp/${FFMPEG_BUILD} && \
    ffmpeg -version | head -1

# Install Node and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs
RUN npm install -g yarn

WORKDIR $INSTALL_PATH

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

COPY package.json yarn.lock ./
RUN yarn install

COPY . .

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
