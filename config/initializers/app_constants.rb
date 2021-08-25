# frozen_string_literal: true
APP_NAME = 'Phish.in'
CONTACT_EMAIL = 'phish.in.music@gmail.com'
DEVISE_EMAIL_FROM = 'Phish.in <noreply@phish.in>'
DESCRIPTION = 'Phish.in is an open source archive of live Phish audio. Stream legal audience recordings using the web UI or API.'

CACHE_TTL = 10.minutes
FIRST_CHAR_LIST = ('A'..'Z').to_a + ['#']
MAX_PLAYLISTS_PER_USER = 20
MIN_SEARCH_TERM_LENGTH = 3
TIME_ZONE = 'Eastern Time (US & Canada)'

APP_CONTENT_PATH =
  if Rails.env.test?
    Rails.root.join('tmp/content')
  elsif ENV['IN_DOCKER']
    '/content'
  else
    ENV['APP_CONTENT_PATH']
  end

IMPORT_DIR = "#{APP_CONTENT_PATH}/import"

APP_BASE_URL =
  if Rails.env.in?(%w[development test])
    'http://localhost:3000'
  else
    'https://phish.in'
  end

ERAS = {
  '1.0' => %w[1983-1987] + (1988..2000).map(&:to_s),
  '2.0' => (2002..2004).map(&:to_s),
  '3.0' => (2009..2020).map(&:to_s),
  '4.0' => ['2021']
}.freeze

SET_NAMES = {
  'S' => 'Soundcheck',
  '1' => 'Set 1',
  '2' => 'Set 2',
  '3' => 'Set 3',
  '4' => 'Set 4',
  'E' => 'Encore',
  'E2' => 'Encore 2',
  'E3' => 'Encore 3'
}.freeze

TAGIN_TAGS = [
  'A Cappella',
  'Alt Lyric',
  'Alt Rig',
  'Alt Version',
  'Audience',
  'Banter',
  'Famous',
  'Guest',
  'Narration',
  'Sample',
  'Signal',
  'Tease'
].freeze
