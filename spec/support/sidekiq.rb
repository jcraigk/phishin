require "sidekiq/testing"
Sidekiq::Testing.fake!

RSpec.configure do |config|
  config.before do
    Sidekiq::Worker.clear_all
  end

  config.before(:all, :enable_sidekiq) do
    Sidekiq::Testing.inline!
  end

  config.after(:all, :enable_sidekiq) do
    Sidekiq::Testing.fake!
  end
end
