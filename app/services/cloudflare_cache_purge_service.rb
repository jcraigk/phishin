class CloudflareCachePurgeService < BaseService
  param :url

  def call
    return unless url.present?
    purge_cloudflare_cache
  end

  private

  def purge_cloudflare_cache
    response = Typhoeus.post(
      "https://api.cloudflare.com/client/v4/zones/#{cloudflare_zone_id}/purge_cache",
      headers: {
        "X-Auth-Email" => cloudflare_email,
        "X-Auth-Key" => cloudflare_api_key,
        "Content-Type" => "application/json"
      },
      body: { files: [ url ] }.to_json
    )

    if response.success?
      Rails.logger.info("Successfully purged Cloudflare cache for #{url}")
    else
      Rails.logger.error("Failed to purge Cloudflare cache: #{response.body}")
    end
  end

  def cloudflare_api_key
    ENV.fetch("CLOUDFLARE_API_KEY")
  end

  def cloudflare_zone_id
    ENV.fetch("CLOUDFLARE_ZONE_ID")
  end

  def cloudflare_email
    ENV.fetch("CLOUDFLARE_EMAIL")
  end
end
