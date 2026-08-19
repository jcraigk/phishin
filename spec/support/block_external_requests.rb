module BlockExternalRequests
  Error = Class.new(StandardError)

  MESSAGE = "Real HTTP request blocked in specs: %s %s\n" \
            "Stub it (e.g. `allow(Typhoeus).to receive(:get)`) rather than " \
            "calling the network.".freeze

  def self.blocked!(verb, url)
    raise Error, format(MESSAGE, verb.to_s.upcase, url)
  end
end

RSpec.configure do |config|
  # Nothing in the suite should reach the network: a real call is slow, flaky,
  # can cost money (Anthropic), and can mutate live data (Google Sheets).
  # Specs stub these explicitly; this is the backstop for anything that forgets.
  config.before do
    allow(Typhoeus).to receive(:get) { |url, *| BlockExternalRequests.blocked!(:get, url) }
    allow(Typhoeus).to receive(:post) { |url, *| BlockExternalRequests.blocked!(:post, url) }
    allow(Net::HTTP).to receive(:get_response) { |uri, *| BlockExternalRequests.blocked!(:get, uri) }
  end
end
