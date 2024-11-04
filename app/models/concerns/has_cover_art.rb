require "mini_magick"

module HasCoverArt
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def cover_art_urls
      {
        large: blob_url(cover_art, placeholder: "cover-art-large.jpg"),
        medium: blob_url(cover_art, variant: :medium, placeholder: "cover-art-medium.jpg"),
        small: blob_url(cover_art, variant: :small, placeholder: "cover-art-small.jpg")
      }
    end

    def album_cover_url
      blob_url(album_cover, placeholder: "cover-art-large.jpg")
    end

    def album_zip_url
      blob_url(album_zip)
    end

    def cover_art_path
      attachment_path(cover_art)
    end

    def album_cover_path
      attachment_path(album_cover)
    end

    def album_zip_path
      attachment_path(album_zip)
    end

    def attach_cover_art_by_url(image_url, zoom: 0)
      attach_cover_art(image_url: image_url, zoom: zoom)
    end

    def attach_cover_art_by_path(file_path, zoom: 0)
      attach_cover_art(file_path: file_path, zoom: zoom)
    end

    private

    def attach_cover_art(image_url: nil, file_path: nil, zoom: 0)
      Tempfile.create([ "cover_art_#{SecureRandom.hex}", ".jpg" ]) do |temp_jpg|
        image = fetch_image(image_url, file_path)
        process_image(image, temp_jpg.path, zoom)
        cover_art.attach \
          io: File.open(temp_jpg.path),
          filename: "cover_art_#{id}.jpg",
          content_type: "image/jpeg"
      end
    end

    def fetch_image(image_url, file_path)
      if image_url
        response = Typhoeus.get(image_url)
        raise "Failed to download image: #{response.body}" unless response.success?

        Tempfile.create("cover_art_#{SecureRandom.hex}") do |temp_png|
          temp_png.binmode
          temp_png.write(response.body)
          temp_png.rewind
          MiniMagick::Image.open(temp_png.path)
        end
      elsif file_path
        MiniMagick::Image.open(file_path)
      end
    end

    def process_image(image, output_path, zoom)
      crop_image(image, zoom) if zoom > 0
      image.resize "1024x1024"
      image.format "jpg"
      image.quality 90
      image.strip
      image.write(output_path)
    end

    def crop_image(image, zoom)
      factor = zoom / 100.0
      new_width = (image.width * (1 - factor)).to_i
      new_height = (image.height * (1 - factor)).to_i
      image.crop \
        "#{new_width}x#{new_height}+#{(image.width - new_width) / 2}+" \
        "#{(image.height - new_height) / 2}"
    end

    def attachment_path(attachment)
      return unless attachment.attached?
      ActiveStorage::Blob.service.path_for(attachment.blob.key)
    end
  end
end
