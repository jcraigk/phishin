class CoverArtBlobLocator < ApplicationService
  param :url

  def call
    raise "Cover art service returned no image URL" if url.blank?
    ActiveStorage::Blob.find_by!(key: blob_key)
  end

  private

  def blob_key
    url.split("/blob/").last.to_s.sub(/\.\w+\z/, "")
  end
end
