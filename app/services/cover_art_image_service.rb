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
      nil
    # Otherwise, generate new cover art
    else
      response = Typhoeus.post(
        "https://api.openai.com/v1/images/generations",
        headers: {
          "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_TOKEN")}",
          "Content-Type" => "application/json"
        },
        body: {
          model: "dall-e-3",
          style: "vivid", # DALL-E 3 default
          prompt: show.cover_art_prompt,
          n: 1, # DALL-E requirement
          size: "1024x1024",
          quality: "hd"
        }.to_json
      )

      if response.success?
        result = JSON.parse(response.body)
        image_url = result["data"].first["url"]
        show.attach_cover_art_by_url(image_url) unless dry_run
        image_url
      else
        raise "Failed to generate cover art: #{response.body}"
      end
    end
  end
end
