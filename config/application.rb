require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "active_record/railtie"

Bundler.require(*Rails.groups)

module Phishin
  class Application < Rails::Application
    # Custom app config
    config.app_name = "Phish.in"
    config.web_host = ENV.fetch("WEB_HOST", nil)
    config.base_url =
      "#{config.web_host ? "https" : "http"}://#{config.web_host || "localhost:3000"}"
    config.app_desc =
      "#{config.app_name} is an open source archive of live Phish audience recordings"
    config.first_char_list = ("A".."Z").to_a + [ "#" ]
    config.max_playlists_per_user = 46
    config.min_search_term_length = 3
    config.time_zone = "Eastern Time (US & Canada)"
    config.oauth_google_key = ENV.fetch("OAUTH_GOOGLE_KEY", nil)
    config.oauth_google_secret = ENV.fetch("OAUTH_GOOGLE_SECRET", nil)
    config.content_path =
      ENV.fetch("APP_CONTENT_PATH", nil) ||
        (Rails.env.test? ? Rails.root.join("tmp/content") : "/content")
    config.content_import_path = "#{config.content_path}/import"
    config.content_base_url =
      if ENV.fetch("PRODUCTION_CONTENT", nil) == "true"
        "https://phish.in"
      else
        config.base_url
      end

    # Rails config
    config.load_defaults 7.2
    config.active_job.queue_adapter = :sidekiq
    config.action_mailer.default_url_options = { host: config.base_url }
    config.action_mailer.smtp_settings = {
      user_name: ENV.fetch("SMTP_USERNAME", nil),
      password: ENV.fetch("SMTP_PASSWORD", nil),
      address: ENV.fetch("SMTP_ADDRESS", nil),
      port: 587,
      authentication: :plain
    }
    config.hosts << config.web_host if config.web_host
  end
end

App = Rails.configuration
Rails.application.routes.default_url_options[:host] = App.base_url

# Constants
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
