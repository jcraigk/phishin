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
  config.reuse_server = true
end

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument '--headless=new'
  options.add_argument '--disable-gpu'
  options.add_argument '--no-sandbox'
  options.add_argument '--disable-dev-shm-usage'
  options.add_argument '--window-size=1366,768'
  options.add_argument '--disable-backgrounding-occluded-windows'
  options.add_argument '--disable-renderer-backgrounding'
  options.add_argument '--disable-background-timer-throttling'
  options.add_argument '--disable-ipc-flooding-protection'
  options.add_preference(:page_load_strategy, 'normal')

  driver = Capybara::Selenium::Driver.new(app, browser: :chrome, options:, timeout: 60)

  at_exit do
    driver.quit
  rescue StandardError
    # Ignore errors during shutdown
  end

  driver
end

Capybara::Screenshot.register_driver(:chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end
Capybara::Screenshot.prune_strategy = :keep_last_run

# Clear localStorage before each JavaScript test to prevent state pollution
RSpec.configure do |config|
  config.before(:each, :js) do |example|
    example.metadata[:capybara_retry_count] ||= 0
    visit "/"
    page.execute_script("localStorage.clear()")
    page.execute_script("sessionStorage.clear()")
  rescue StandardError => e
    if example.metadata[:capybara_retry_count] < 3
      example.metadata[:capybara_retry_count] += 1
      Capybara.send(:session_pool).delete([ Capybara.current_driver, Capybara.current_session.server&.port ])
      sleep 0.5
      retry
    else
      raise e
    end
  end

  config.prepend_after(:each, :js) do
    page.driver.browser.navigate.to("about:blank")
  rescue StandardError
    # Browser is in a bad state, force restart by removing from session pool
    begin
      page.driver.quit
    rescue StandardError
      # Ignore
    end
    Capybara.send(:session_pool).delete([ Capybara.current_driver, Capybara.current_session.server&.port ])
    sleep 0.5
  end
end
