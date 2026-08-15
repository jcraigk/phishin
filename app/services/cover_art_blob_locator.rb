# CoverArtImageService reports the image it uploaded as a public URL rather than
# a blob, because its non-admin callers only ever hand that URL to the attach
# helper. The admin flow needs the blob itself so the image can be held as a
# candidate, so this resolves the URL back to its record.
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
