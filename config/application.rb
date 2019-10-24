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
    config.load_defaults 6.0
    config.action_controller.permit_all_parameters = true
  end
end
