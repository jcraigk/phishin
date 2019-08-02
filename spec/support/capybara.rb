# frozen_string_literal: true
require 'capybara/rails'
require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'selenium/webdriver'

Capybara.configure do |config|
  config.default_max_wait_time = 5
  config.default_driver = :rack_test
  config.javascript_driver = :chrome
  config.server = :puma, { Silent: true }
  config.raise_server_errors = false
  config.asset_host = 'http://localhost:3000'
end

Capybara.register_driver :chrome do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument 'headless'
  options.add_argument 'disable-gpu'
  options.add_argument 'no-sandbox'
  options.add_argument 'window-size=1366,768'
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara::Screenshot.register_driver(:chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end
Capybara::Screenshot.prune_strategy = :keep_last_run
