require "rails_helper"

RSpec.describe "Dynamic rendering (PrerenderMiddleware)" do
  let(:googlebot) do
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
  end

  around do |example|
    original = ENV["PRERENDER_SERVICE_URL"]
    example.run
    ENV["PRERENDER_SERVICE_URL"] = original
    Typhoeus::Expectation.clear
  end

  context "when PRERENDER_SERVICE_URL is set and the request is from a crawler" do
    before { ENV["PRERENDER_SERVICE_URL"] = "http://prerender.test" }

    it "serves the prerendered snapshot instead of the SPA shell" do
      Typhoeus.stub("http://prerender.test/http://www.example.com/2026-04-25").and_return(
        Typhoeus::Response.new(code: 200, body: "<html><body>PRERENDERED CONTENT</body></html>")
      )

      get "/2026-04-25", headers: { "HTTP_USER_AGENT" => googlebot }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PRERENDERED CONTENT")
    end

    it "falls open to the SPA when the prerender service errors" do
      Typhoeus.stub(%r{prerender\.test}).and_return(Typhoeus::Response.new(code: 500, body: "err"))

      get "/faq", headers: { "HTTP_USER_AGENT" => googlebot }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FAQ - Phish.in")
      expect(response.body).not_to include("PRERENDERED CONTENT")
    end

    it "does not prerender API requests" do
      get "/api/v2/years", headers: { "HTTP_USER_AGENT" => googlebot }

      expect(response.body).not_to include("PRERENDERED CONTENT")
    end
  end

  context "when the request is from a normal browser" do
    before { ENV["PRERENDER_SERVICE_URL"] = "http://prerender.test" }

    it "passes through to the SPA" do
      get "/faq", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Chrome/120" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FAQ - Phish.in")
    end
  end

  context "when PRERENDER_SERVICE_URL is unset" do
    before { ENV.delete("PRERENDER_SERVICE_URL") }

    it "passes crawlers through unchanged" do
      get "/faq", headers: { "HTTP_USER_AGENT" => googlebot }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("FAQ - Phish.in")
    end
  end
end
