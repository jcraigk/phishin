require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
Dir[Rails.root.join('spec/support/**/*')].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  ReactOnRails::TestHelper.configure_rspec_to_compile_assets(config)

  # ReactOnRails::TestHelper.configure_rspec_to_compile_assets(config, :requires_webpack_assets)
  # config.define_derived_metadata(file_path: %r{spec/features}) do |metadata|
  #   metadata[:requires_webpack_assets] = true
  # end

  config.fixture_paths = [ "#{Rails.root}/spec/fixtures" ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.order = 'random'

  config.include ActiveSupport::Testing::TimeHelpers
  config.include ApiHelper
  config.include FeatureHelpers

  config.after do
    Faker::UniqueGenerator.clear
  end
end
