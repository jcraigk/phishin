FROM ruby:2.5.1
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
WORKDIR .
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN ln -s /content/tracks/audio_files ./public/audio
EXPOSE 3000
