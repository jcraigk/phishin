module HasCoverArt
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    def cover_art_urls
      %i[medium small].each_with_object({}) do |variant, memo|
        memo[variant] = cover_art_variant_url(variant)
      end
    end

    def album_cover_url
      if album_cover.attached?
        Rails.application.routes.url_helpers.rails_blob_url(album_cover)
      else
        ActionController::Base.helpers.asset_pack_path \
          "static/images/placeholders/cover-art-medium.jpg"
      end
    end

    def generate_album!
      CoverArtPromptService.call(self)
      CoverArtImageService.call(self)
      AlbumCoverService.call(self)
      tracks.each(&:apply_id3_tags)
      AlbumZipJob.perform_async(id)
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
  end
end
