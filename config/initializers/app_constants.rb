# frozen_string_literal: true
APP_NAME = "phish.in'"
APP_EMAIL = 'phish.in.music@gmail.com'
DEVISE_EMAIL_FROM = "phish.in' <noreply@phish.in>"

ALBUM_CACHE_MAX_SIZE = 50.gigabytes
ALBUM_TIMEOUT = 10.seconds

CACHE_TTL = 10.minutes
FIRST_CHAR_LIST = ('A'..'Z').to_a + ['#']
MAX_PLAYLISTS_PER_USER = 20

if Rails.env.in?(%w[development test])
  APP_BASE_URL = 'http://localhost:3000'
  APP_CONTENT_PATH = '/htdocs/app_content/phishin/'
  TMP_PATH = '/htdocs/app_content/phishin/tmp/'
else
  APP_BASE_URL = 'https://phish.in'
  APP_CONTENT_PATH = '/var/www/app_content/phishin/'
  TMP_PATH = '/var/www/app_content/phishin/tmp/'
end

ERAS = {
  '1.0' => %w[1983-1987] + (1988..2000).map(&:to_s),
  '2.0' => (2002..2004).map(&:to_s),
  '3.0' => (2009..2017).map(&:to_s)
}.freeze

IMPORT_DIR = "#{Rails.root}/import"
