module HasCoverArt
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def cover_art_urls
      {
        medium: attachment_url(cover_art, "cover-art-medium.jpg"),
        small: cover_art_variant_url(:small)
      }
    end

    def album_cover_url
      attachment_url(album_cover, "cover-art-medium.jpg")
    end

    def generate_album_cover!
      CoverArtPromptService.call(self)
      CoverArtImageService.call(self)
      AlbumCoverService.call(self)
      tracks.each(&:apply_id3_tags)
    end

    def album_zip_url
      return unless album_zip.attached?
      Rails.application.routes.url_helpers.rails_blob_url(album_zip)
    end

    private

    def cover_art_variant_url(variant)
      if cover_art.attached?
        Rails.application.routes.url_helpers.rails_representation_url(
          cover_art.variant(variant).processed
        )
      else
        ActionController::Base.helpers.asset_pack_path(
          "static/images/placeholders/cover-art-#{variant}.jpg"
        )
      end
    end

    def attachment_url(attachment, placeholder)
      if attachment.attached?
        Rails.application.routes.url_helpers.rails_blob_url(attachment)
      else
        path = "static/images/placeholders/#{placeholder}"
        ActionController::Base.helpers.asset_pack_path(path)
      end
    end
  end
end
