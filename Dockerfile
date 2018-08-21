FROM ruby:2.5.1

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# Bundle install, copy app
WORKDIR .
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

# Symlink audio files to Rails public folder
RUN ln -s /content/tracks/audio_files ./public/audio

EXPOSE 80
CMD bundle exec puma -b tcp://0.0.0.0:80
