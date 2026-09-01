module OpenaiEnv
  PLACEHOLDER_TOKEN = "test-openai-token-not-a-real-key".freeze
end

RSpec.configure do |config|
  config.around(:each, :openai) do |example|
    original = ENV.fetch("OPENAI_API_TOKEN", nil)
    ENV["OPENAI_API_TOKEN"] = OpenaiEnv::PLACEHOLDER_TOKEN
    example.run
  ensure
    original.nil? ? ENV.delete("OPENAI_API_TOKEN") : ENV["OPENAI_API_TOKEN"] = original
  end
end
