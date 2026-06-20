# Dynamic rendering: when a crawler requests an HTML page, fetch a fully-rendered
# snapshot from a self-hosted prerender service (headless Chrome) and serve that
# instead of the empty SPA shell. Humans are passed straight through to the SPA.
#
# Inactive unless PRERENDER_SERVICE_URL is set, and fails open: if the prerender
# service errors or times out, the crawler simply gets the normal SPA response.
class PrerenderMiddleware
  # Lowercased substrings matched against the User-Agent. Googlebot renders JS on
  # its own, but Google's guidance is to serve it the prerendered HTML too.
  CRAWLER_USER_AGENTS = %w[
    googlebot bingbot yandex baiduspider duckduckbot slurp
    applebot facebookexternalhit facebookcatalog twitterbot linkedinbot
    embedly quora pinterest slackbot vkshare w3c_validator redditbot
    discordbot telegrambot whatsapp
  ].freeze

  # Asset-ish extensions never worth prerendering.
  EXTENSION_BLACKLIST = %w[
    .js .css .json .xml .less .png .jpg .jpeg .gif .webp .pdf .doc .txt .zip
    .mp3 .mp4 .wav .flac .ogg .ico .svg .woff .woff2 .ttf .eot .map .gz
  ].freeze

  PREFIX_BLACKLIST = %w[/api /sidekiq /blob /packs /assets /feeds].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    return @app.call(env) unless should_prerender?(request)

    prerendered_response(request) || @app.call(env)
  end

  private

  def service_url
    ENV["PRERENDER_SERVICE_URL"].presence
  end

  def should_prerender?(request)
    return false if service_url.nil?
    return false unless request.get?
    return false if PREFIX_BLACKLIST.any? { |p| request.path.start_with?(p) }
    return false if EXTENSION_BLACKLIST.any? { |ext| request.path.downcase.end_with?(ext) }

    crawler?(request.user_agent) || request.params.key?("_escaped_fragment_")
  end

  def crawler?(user_agent)
    return false if user_agent.blank?
    agent = user_agent.downcase
    CRAWLER_USER_AGENTS.any? { |bot| agent.include?(bot) }
  end

  def prerendered_response(request)
    response = Typhoeus.get(prerender_url(request), headers: prerender_headers, timeout: 30)
    return nil unless response.success?

    [ 200, { "Content-Type" => "text/html; charset=utf-8" }, [ response.body ] ]
  rescue StandardError => e
    Rails.logger.warn("[Prerender] #{e.class}: #{e.message}")
    nil
  end

  # Prerender protocol: GET {service}/{full original URL}
  def prerender_url(request)
    "#{service_url.chomp('/')}/#{request.url}"
  end

  def prerender_headers
    headers = { "User-Agent" => "PhishinPrerender" }
    token = ENV["PRERENDER_TOKEN"].presence
    headers["X-Prerender-Token"] = token if token
    headers
  end
end
