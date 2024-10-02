class CoverArtImageService < BaseService
  extend Dry::Initializer

  param :show

  def call
    generate_and_save_cover_art
  end

  private

  def generate_and_save_cover_art
    # Get variation on venue run cover if part of run
    if show.cover_art_parent_show_id
      parent_show = Show.find(show.cover_art_parent_show_id)
      response = Typhoeus.post(
        "https://api.openai.com/v1/images/variations",
        headers: {
          "Authorization" => "Bearer #{openai_api_token}",
          "Content-Type" => "multipart/form-data"
        },
        body: {
          image:  File.open(parent_show.cover_art.path, "rb"),
          n: 1,
          size: "1024x1024"
        }
      )
      cover_art_file.close
    else
      # Generate a new image from prompt
      response = Typhoeus.post(
        "https://api.openai.com/v1/images/generations",
        headers: {
          "Authorization" => "Bearer #{openai_api_token}",
          "Content-Type" => "application/json"
        },
        body: {
          prompt: show.cover_art_prompt,
          n: 1,
          size: "1024x1024"
        }.to_json
      )
    end

    if response.success?
      result = JSON.parse(response.body)
      image_url = result["data"].first["url"]
      puts "IMAGE: #{image_url}"
      download_and_convert_to_jpg(image_url)
    else
      raise "Failed to generate cover art: #{response.body}"
    end
  rescue StandardError => e
    binding.irb
  end

  def download_and_convert_to_jpg(image_url)
    image_response = Typhoeus.get(image_url)

    if image_response.success?
      # Save the image as a temporary PNG file
      Tempfile.create([ "cover_art", ".png" ]) do |temp_png|
        temp_png.binmode
        temp_png.write(image_response.body)
        temp_png.rewind

        # Convert to JPG and generate derivatives
        image = Vips::Image.new_from_file(temp_png.path)
        Tempfile.create([ "cover_art", ".jpg" ]) do |temp_jpg|
          image.jpegsave(temp_jpg.path)
          show.cover_art = File.open(temp_jpg.path)
          # TODO: Generate derivatives
          show.save!
        end
      end
    else
      raise "Failed to download cover art: #{image_response.body}"
    end
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end
end
