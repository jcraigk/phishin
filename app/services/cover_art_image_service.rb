require "mini_magick"

class CoverArtImageService < BaseService
  param :show

  def call
    generate_and_save_cover_art
  end

  private

  def generate_and_save_cover_art
    # Use the parent show's cover art if part of a run
    # if show.cover_art_parent_show_id
    #   parent_show = Show.find(show.cover_art_parent_show_id)
    #   show.cover_art.attach(parent_show.cover_art.blob)
    # # Otherwise, generate new cover art
    # else
      response = Typhoeus.post(
        "https://api.openai.com/v1/images/generations",
        headers: {
          "Authorization" => "Bearer #{openai_api_token}",
          "Content-Type" => "application/json"
        },
        body: {
          model: "dall-e-3",
          prompt: show.cover_art_prompt,
          n: 1,
          size: "1024x1024"
        }.to_json
      )

      if response.success?
        result = JSON.parse(response.body)
        image_url = result["data"].first["url"]
        download_and_convert_to_jpg(image_url)
      else
        raise "Failed to generate cover art: #{response.body}"
      end
    # end
  end

  def download_and_convert_to_jpg(image_url)
    image_response = Typhoeus.get(image_url)

    if image_response.success?
      # Save the image as a temporary PNG file
      Tempfile.create([ "cover_art_#{SecureRandom.hex}", ".png" ]) do |temp_png|
        temp_png.binmode
        temp_png.write(image_response.body)
        temp_png.rewind

        # Convert to JPG and generate derivatives using MiniMagick
        Tempfile.create([ "cover_art_#{SecureRandom.hex}", ".jpg" ]) do |temp_jpg|
          image = MiniMagick::Image.open(temp_png.path)
          image.format "jpg"
          image.quality 90
          image.strip
          image.write(temp_jpg.path)

          # Attach the converted JPG image to the show
          show.cover_art.attach \
            io: File.open(temp_jpg.path),
            filename: "cover_art_#{show.id}.jpg",
            content_type: "image/jpeg"
        end
      end
    else
      raise "Failed to download cover art: #{image_response.body}"
    end
  end

  def create_variants
    show.cover_art.variant(resize_to_limit: [ 36, 36 ]).processed
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end
end
