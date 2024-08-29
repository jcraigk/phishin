class PlausibleEventJob
  include Sidekiq::Job

  def perform(url, user_agent, client_ip, api_key_id)
    response = Typhoeus.post \
      "https://plausible.io/api/event",
      headers: {
        "User-Agent" => user_agent,
        "X-Client-IP-Address" => client_ip,
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{ENV.fetch("PLAUSIBLE_API_KEY", nil)}"
      },
      body: {
        name: "pageview",
        url: url,
        domain: ENV.fetch("WEB_HOST", nil),
        props: {
          api_key_id:
        }
      }.to_json

    unless response.success?
      Rails.logger.error "Plausible logging failed: #{response.code} - #{response.body}"
    end
  end
end
