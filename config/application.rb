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
    # TODO: Remove this!  Was causing errors on
    # http://phish.in/search-map?lat=44.4758825&lng=-73.21207199999998&distance=10 for example
    config.action_controller.permit_all_parameters = true
  end
end
