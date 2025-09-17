require "mini_magick"

module HasCoverArt
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def cover_art_urls
      placeholder_prefix = (respond_to?(:audio_status) && audio_status == "missing") ?
                          "missing-audio-cover-art" : "cover-art"

      return %i[large medium small].index_with { |size| "#{App.base_url}/placeholders/#{placeholder_prefix}-#{size}.jpg" } unless cover_art.attached?

      blob_key = cover_art.blob.key

      %i[large medium small].index_with do |size|
        if size == :large
          # Large uses the original blob
          "#{App.content_base_url}/blob/#{blob_key}.jpg"
        else
          # For medium and small, try to use preloaded variant records
          variant_record = cover_art.blob.variant_records.find { |vr| vr.variation_digest == variant_digest_for_size(size) }
          if variant_record&.image_attachment&.blob
            "#{App.content_base_url}/blob/#{variant_record.image_attachment.blob.key}.jpg"
          else
            # Fallback to blob_url method
            blob_url(cover_art, variant: size, ext: :jpg) || "/placeholders/#{placeholder_prefix}-#{size}.jpg"
          end
        end
      end
    end

    def album_cover_url
      placeholder = (respond_to?(:audio_status) && audio_status == "missing") ?
                    "missing-audio-cover-art-large.jpg" : "cover-art-large.jpg"
      blob_url(album_cover, placeholder:, ext: :jpg)
    end

    def album_zip_url
      blob_url(album_zip, ext: :zip)
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
      attach_cover_art(image_url:, zoom:)
    end

    def attach_cover_art_by_path(file_path, zoom: 0)
      attach_cover_art(file_path:, zoom:)
    end

    private

    def variant_digest_for_size(size)
      # Calculate the variation digest for the given size
      # This matches what ActiveStorage uses internally
      # Reduces queries, eliminates N+1
      case size
      when :medium
        ActiveStorage::Variation.new(resize_to_limit: [ 256, 256 ]).digest
      when :small
        ActiveStorage::Variation.new(resize_to_limit: [ 40, 40 ]).digest
      end
    end

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
