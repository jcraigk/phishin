# frozen_string_literal: true
require 'database_cleaner'

module DatabaseCleanerHelpers
  def clean_db
    DatabaseCleaner.clean_with :truncation
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:truncate_db] ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end

  config.include DatabaseCleanerHelpers
end
