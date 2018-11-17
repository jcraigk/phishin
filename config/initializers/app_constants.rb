# frozen_string_literal: true
APP_NAME = "phish.in'"
APP_EMAIL = 'phish.in.music@gmail.com'
DEVISE_EMAIL_FROM = "phish.in' <noreply@phish.in>"

CACHE_TTL = 10.minutes
FIRST_CHAR_LIST = ('A'..'Z').to_a + ['#']
MAX_PLAYLISTS_PER_USER = 20

APP_CONTENT_PATH = '/content'
IMPORT_DIR = APP_CONTENT_PATH + '/import'

APP_BASE_URL =
  if Rails.env.in?(%w[development test])
    'http://localhost'
  else
    'https://phish.in'
  end

ERAS = {
  '1.0' => %w[1983-1987] + (1988..2000).map(&:to_s),
  '2.0' => (2002..2004).map(&:to_s),
  '3.0' => (2009..2018).map(&:to_s)
}.freeze
