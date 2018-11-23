# frozen_string_literal: true
require 'capybara/rails'
require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'selenium/webdriver'

Capybara.server = :puma, { Silent: true }

if ENV['IN_DOCKER']
  Capybara.register_driver :remote_chrome do |app|
    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: ENV.fetch('SELENIUM_URL', 'http://localhost:4444/wd/hub'),
      desired_capabilities: :chrome
    )
  end

  Capybara::Screenshot.register_driver(:remote_chrome) do |driver, path|
    driver.browser.save_screenshot(path)
  end
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

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_USER_AGENT' => 'Chrome' })
end

Capybara.configure do |config|
  config.default_max_wait_time = 2
  config.default_driver = :rack_test
  if ENV['IN_DOCKER']
    config.javascript_driver = :remote_chrome
    config.app_host = 'http://app.test:3001'
    config.server_host = '0.0.0.0'
    config.server_port = 3001
  else
    config.javascript_driver = :chrome
  end
end

RSpec.configure do |config|
  config.append_after(:each, type: :feature) do
    Capybara.reset_sessions!
  end
end

Capybara.asset_host = 'http://localhost:3000'
Capybara::Screenshot.prune_strategy = :keep_last_run
