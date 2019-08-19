# frozen_string_literal: true
require File.expand_path('boot', __dir__)
require 'rails/all'

Bundler.require(*Rails.groups) if defined?(Bundler)

module Phishin
  class Application < Rails::Application
    config.assets.precompile += %w[
      soundmanager2.swf
      soundmanager2_flash9.swf
    ]

    config.action_controller.permit_all_parameters = true

    # config.load_defaults '6.0'
  end
end
