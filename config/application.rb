# frozen_string_literal: true
require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)

module Phishin
  class Application < Rails::Application
    config.load_defaults = '6.1'
    config.action_controller.permit_all_parameters = true

    ActionMailer::Base.smtp_settings = {
      user_name: ENV['SMTP_USERNAME'],
      password: ENV['SMTP_PASSWORD'],
      address: 'smtp.gmail.com',
      port: 587,
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
end
