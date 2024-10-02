require "typhoeus"

class RegenerateTrackWaveformJob
  include Sidekiq::Job

  def perform(track_id)
    track = Track.find_by(id: track_id)
    return unless track

    track.generate_waveform_image
    purge_cloudflare_cache(track.waveform_image_url)
  end

  private

  def purge_cloudflare_cache(url)
    return unless url

    cloudflare_api_key = ENV.fetch("CLOUDFLARE_API_KEY")
    cloudflare_zone_id = ENV.fetch("CLOUDFLARE_ZONE_ID")
    cloudflare_email = ENV.fetch("CLOUDFLARE_EMAIL")

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
      Rails.logger.info("Cloudflare cache purged: #{url}")
    else
      Rails.logger.error("Cloudflare cache purge failed: #{response.body}")
    end
  end
end
