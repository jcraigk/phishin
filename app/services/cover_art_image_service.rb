class CoverArtImageService < ApplicationService
  param :show
  option :dry_run, default: -> { false }

  def call
    generate_and_save_cover_art
  end

  private

  def generate_and_save_cover_art
    # Use the parent show's cover art if part of a run
    if show.cover_art_parent_show_id
      parent_show = Show.find(show.cover_art_parent_show_id)
      show.cover_art.attach(parent_show.cover_art.blob) unless dry_run
      return
    end

    response = Typhoeus.post(
      "https://api.openai.com/v1/images/generations",
      headers: {
        "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_TOKEN")}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-image-2",
        prompt: show.cover_art_prompt,
        n: 1,
        size: "1024x1024",
        quality: "high"
      }.to_json
    )

    raise "Failed to generate cover art: #{response.body}" unless response.success?

    result = JSON.parse(response.body)
    url = upload_candidate(result["data"].first["b64_json"])
    show.attach_cover_art_by_url(url) unless dry_run
    url
  end

  def upload_candidate(b64)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(Base64.decode64(b64)),
      filename: "cover_art_candidate_#{SecureRandom.hex}.png",
      content_type: "image/png"
    )
    "#{App.base_url}/blob/#{blob.key}.png"
  end
end
