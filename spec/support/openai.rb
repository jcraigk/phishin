# The image and chat services read OPENAI_API_TOKEN through ENV.fetch, which
# raises in the test environment because no token is configured there. That
# absence is a safety net worth keeping, so specs that exercise those services
# borrow a placeholder token for the duration of the example instead of the
# suite carrying a real one.
#
# A token alone reaches nothing: examples tagged :openai must also stub
# Typhoeus.post, since every one of those endpoints is billed per call.
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
