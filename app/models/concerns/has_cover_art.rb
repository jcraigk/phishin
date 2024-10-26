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

    def attach_cover_art_by_url(image_url, zoom: 0)
      attach_cover_art(image_url: image_url, zoom: zoom)
    end

    def attach_cover_art_by_path(file_path, zoom: 0)
      attach_cover_art(file_path: file_path, zoom: zoom)
    end

    private

    def attach_cover_art(image_url: nil, file_path: nil, zoom: 0)
      Tempfile.create([ "cover_art_#{SecureRandom.hex}", ".jpg" ]) do |temp_jpg| # rubocop:disable Metrics/BlockLength
        image = if image_url
          image_response = Typhoeus.get(image_url)
          raise "Failed to download image: #{image_response.body}" unless image_response.success?
          Tempfile.create("cover_art_#{SecureRandom.hex}") do |temp_png|
            temp_png.binmode
            temp_png.write(image_response.body)
            temp_png.rewind
            MiniMagick::Image.open(temp_png.path)
          end
        elsif file_path
          MiniMagick::Image.open(file_path)
        end

        # Zoom in by cropping the specified percentage from each side
        if zoom > 0
          zoom_factor = zoom / 100.0
          width = image.width
          height = image.height
          new_width = (width * (1 - zoom_factor)).to_i
          new_height = (height * (1 - zoom_factor)).to_i
          image.crop \
            "#{new_width}x#{new_height}+#{(width - new_width) / 2}+#{(height - new_height) / 2}"
        end

        image.resize "1024x1024"
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
