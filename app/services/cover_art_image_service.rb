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
    path = write_temp_image(result["data"].first["b64_json"])
    show.attach_cover_art_by_path(path) unless dry_run
    path
  end

  def write_temp_image(b64)
    path = Rails.root.join("tmp", "cover_art_#{SecureRandom.hex}.png").to_s
    File.binwrite(path, Base64.decode64(b64))
    path
  end
end
