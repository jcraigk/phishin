require "mini_magick"

module HasCoverArt
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def cover_art_urls
      {
        large: attachment_url(cover_art, "cover-art-large"),
        medium: cover_art_variant_url(:medium),
        small: cover_art_variant_url(:small)
      }
    end

    def album_cover_url
      attachment_url(album_cover, "cover-art-large")
    end

    def generate_album!
      CoverArtPromptService.call(self)
      CoverArtImageService.call(self)
      AlbumCoverService.call(self)
      tracks.each do
        _1.apply_id3_tags
        CloudflareCachePurgeService.call(_1.mp3_url)
      end
    end

    def album_zip_url
      return unless album_zip.attached?
      key = album_zip.blob.key
      "#{App.content_base_url}/blob/#{album_zip.blob.key}"
    end

    def cover_art_path
      return unless cover_art.attached?
      ActiveStorage::Blob.service.send(:path_for, cover_art.blob.key)
    end

    def album_cover_path
      return unless album_cover.attached?
      ActiveStorage::Blob.service.send(:path_for, album_cover.blob.key)
    end

    def album_zip_path
      return unless album_zip.attached?
      ActiveStorage::Blob.service.send(:path_for, album_zip.blob.key)
    end

    def attach_cover_art_by_url(image_url)
      image_response = Typhoeus.get(image_url)

      if image_response.success?
        # Save the image as a temporary PNG file
        Tempfile.create("cover_art_#{SecureRandom.hex}") do |temp_png|
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
            cover_art.attach \
              io: File.open(temp_jpg.path),
              filename: "cover_art_#{id}.jpg",
              content_type: "image/jpeg"
          end
        end
      else
        raise "Failed to download image: #{image_response.body}"
      end
    end

    private

    def cover_art_variant_url(variant)
      if cover_art.attached?
        key = cover_art.variant(variant).processed.key
        "#{App.content_base_url}/blob/#{key}"
      else
        placeholder(variant)
      end
    rescue ActiveStorage::FileNotFoundError
      placeholder(variant)
    end

    def placeholder(variant)
      path = ActionController::Base.helpers.asset_pack_path \
        "static/images/placeholders/cover-art-#{variant}.jpg"
    end

    def attachment_url(attachment, placeholder)
      if attachment.attached?
        "#{App.content_base_url}/blob/#{attachment.blob.key}"
      else
        path = ActionController::Base.helpers.asset_pack_path \
          "static/images/placeholders/#{placeholder}.jpg"
      end
    end
  end
end
