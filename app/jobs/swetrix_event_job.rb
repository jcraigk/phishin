class SwetrixEventJob
  include Sidekiq::Job

  def perform(url, user_agent, client_ip)
    response = Typhoeus.post \
      "https://api.swetrix.com/log",
      headers: {
        "User-Agent" => user_agent,
        "X-Client-IP-Address" => client_ip,
        "Content-Type" => "application/json"
      },
      body: {
        pid: ENV.fetch("SWETRIX_PROJECT_ID", nil),
        lc: "en-US",
        pg: url
      }.to_json

    unless response.success?
      Rails.logger.error \
        "Swetrix logging failed: #{response.code} - #{response.body}"
    end
  end
end
