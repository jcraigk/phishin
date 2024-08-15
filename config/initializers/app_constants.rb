APP_NAME = "Phish.in".freeze
APP_DESC = "#{APP_NAME} is an open source archive of live Phish audience recordings".freeze
CONTACT_EMAIL = "phish.in.music@gmail.com".freeze
AUTH_EMAIL_FROM = "Phish.in <noreply@phish.in>".freeze
DESCRIPTION = "An open source archive of live Phish audience recordings".freeze
TWITTER_USER = "@phish_in".freeze
OAUTH_PROVIDERS = ENV.fetch("OAUTH_PROVIDERS", nil).presence&.split(",")&.map(&:to_sym)

CACHE_TTL = 10.minutes
FIRST_CHAR_LIST = ("A".."Z").to_a + [ "#" ]
MAX_PLAYLISTS_PER_USER = 20
MIN_SEARCH_TERM_LENGTH = 3
TIME_ZONE = "Eastern Time (US & Canada)".freeze

APP_CONTENT_PATH =
  if Rails.env.test?
    Rails.root.join("tmp/content")
  elsif ENV.fetch("IN_DOCKER", false)
    "/content"
  else
    ENV.fetch("APP_CONTENT_PATH", "/")
  end

IMPORT_DIR = "#{APP_CONTENT_PATH}/import".freeze

PRODUCTION_BASE_URL = "https://phish.in".freeze
APP_BASE_URL =
  if Rails.env.in?(%w[development test])
    web_host = ENV.fetch("WEB_HOST", nil)
    protocol = web_host ? "https" : "http"
    host = web_host || "localhost:3000"
    "#{protocol}://#{host}"
  else
    PRODUCTION_BASE_URL
  end
PRODUCTION_CONTENT = ENV.fetch("PRODUCTION_CONTENT", "false") == "true"

ERAS = {
  "1.0" => %w[1983-1987] + (1988..2000).map(&:to_s),
  "2.0" => (2002..2004).map(&:to_s),
  "3.0" => (2009..2020).map(&:to_s),
  "4.0" => (2021..2024).map(&:to_s)
}.freeze

SET_NAMES = {
  "P" => "Pre-Show",
  "S" => "Soundcheck",
  "1" => "Set 1",
  "2" => "Set 2",
  "3" => "Set 3",
  "4" => "Set 4",
  "E" => "Encore",
  "E2" => "Encore 2",
  "E3" => "Encore 3"
}.freeze

TAGIN_TAGS = [
  "A Cappella",
  "Alt Lyric",
  "Alt Rig",
  "Alt Version",
  "Audience",
  "Banter",
  "Famous",
  "Guest",
  "Narration",
  "Signal",
  "Tease",
  "Unfinished"
].freeze
