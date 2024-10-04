module HasCoverArt
  extend ActiveSupport::Concern

  included do
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
      tracks.each(&:apply_id3_tags)
      AlbumZipJob.perform_async(id)
    end

    def album_zip_url
      return unless album_zip.attached?
      key = album_zip.blob.key
      "#{App.base_url}/download-show/#{date}"
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

    private

    def cover_art_variant_url(variant)
      if cover_art.attached?
        key = cover_art.variant(variant).processed.key
        "#{App.base_url}/attachments/#{key[0..1]}/#{key[2..3]}/#{key}"
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
        key = attachment.blob.key
        partitioned_key = "#{key[0..1]}/#{key[2..3]}/#{key}"
        "#{App.base_url}/attachments/#{partitioned_key}"
      else
        path = ActionController::Base.helpers.asset_pack_path \
          "static/images/placeholders/#{placeholder}.jpg"
      end
    end
  end
end
