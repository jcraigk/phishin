# frozen_string_literal: true
APP_NAME = "phish.in'"
APP_EMAIL = 'phish.in.music@gmail.com'
DEVISE_EMAIL_FROM = "phish.in' <noreply@phish.in>"

CACHE_TTL = 10.minutes
FIRST_CHAR_LIST = ('A'..'Z').to_a + ['#']
MAX_PLAYLISTS_PER_USER = 20
MIN_SEARCH_TERM_LENGTH = 3

APP_CONTENT_PATH = Rails.env.test? ? "#{Rails.root}/tmp/content" : '/content'
IMPORT_DIR = APP_CONTENT_PATH + '/import'

APP_BASE_URL =
  if Rails.env.in?(%w[ test])
    'http://localhost'
  else
    'https://phish.in'
  end

ERAS = {
  '1.0' => %w[1983-1987] + (1988..2000).map(&:to_s),
  '2.0' => (2002..2004).map(&:to_s),
  '3.0' => (2009..2018).map(&:to_s)
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

TAGIN_TAGS = {
  'A Cappella' => 'Sung without accompaniment',
  'Acoustic' => 'Played on acoustic instruments',
  'Alt Lyric' => 'Atypical lyrics or keyword section',
  'Alt Rig' => 'Band member using atypical gear',
  'Alt Version' => 'Atypical variation on a song',
  'Banter' => 'Band members having a chat',
  'Audience' => 'Audience interacting with band or music',
  'Famous' => 'Famous (specially named) show or track',
  'Guest' => 'Other artists joining the band',
  'Narration' => 'Narrative spoken word',
  'Samples' => 'Audio samples used in performance',
  'Secret Language' => 'Secret language instructions and invocations',
  'Tease' => 'Transient musical reference'
}.freeze
