require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'active_record/railtie'

Bundler.require(*Rails.groups)

module Phishin
  class Application < Rails::Application
    # TODO: Re-enable when devise is updated (silently breaks prod login)
    config.load_defaults 7.2
    config.active_support.cache_format_version = 7.0 # Remove later
    config.hosts << ENV.fetch('WEB_HOST', nil) if ENV['WEB_HOST'].present?
  end
end
