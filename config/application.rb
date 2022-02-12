# frozen_string_literal: true
require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'active_record/railtie'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)

module Phishin
  class Application < Rails::Application
    config.load_defaults = '7.0'
    config.active_record.legacy_connection_handling = false

    config.hosts << ENV['WEB_HOST'] if ENV['WEB_HOST'].present?

    ActionMailer::Base.smtp_settings = {
      user_name: ENV['SMTP_USERNAME'],
      password: ENV['SMTP_PASSWORD'],
      address: ENV['SMTP_ADDRESS'],
      port: 587,
      authentication: :plain
    }
  end
end
