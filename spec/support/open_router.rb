module OpenRouterEnv
  PLACEHOLDER_KEY = "test-openrouter-key-not-a-real-key".freeze
end

RSpec.configure do |config|
  config.around(:each, :open_router) do |example|
    original = ENV.fetch("OPENROUTER_API_KEY", nil)
    ENV["OPENROUTER_API_KEY"] = OpenRouterEnv::PLACEHOLDER_KEY
    example.run
  ensure
    original.nil? ? ENV.delete("OPENROUTER_API_KEY") : ENV["OPENROUTER_API_KEY"] = original
  end
end
