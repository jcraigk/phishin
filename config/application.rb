require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'active_record/railtie'
require_relative '../lib/middleware/mobile_redirect'

Bundler.require(*Rails.groups)

module Phishin
  class Application < Rails::Application
    config.load_defaults 7.1
    config.hosts << ENV.fetch('WEB_HOST', nil) if ENV['WEB_HOST'].present?
    # config.middleware.insert_before 0, Middleware::MobileRedirect
  end
end
