# frozen_string_literal: true
require 'simplecov'
SimpleCov.start

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
Dir[Rails.root.join('spec/support/**/*')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.order = 'random'

  config.include FeatureHelpers
  config.include Warden::Test::Helpers
  config.include AuthHelper, type: :request

  config.after do
    Faker::UniqueGenerator.clear
    Warden.test_reset!
  end
end
