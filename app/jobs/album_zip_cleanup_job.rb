class AlbumZipCleanupJob
  include Sidekiq::Worker

  BUFFER = 5.gigabytes

  def perform
    total_size = get_total_size
    target_size = App.album_zip_disk_limit - BUFFER
    return if total_size <= target_size

    # Continue deleting the oldest attachments until we are under the target limit
    while total_size > target_size
      oldest_blob =
        ActiveStorage::Blob.joins(:attachments)
          .where(active_storage_attachments: { name: "album_zip", record_type: "Show" })
          .order(:created_at)
          .first
      break unless oldest_blob

      attachment = oldest_blob.attachments.find_by(name: "album_zip", record_type: "Show")
      break unless attachment

      byte_size = oldest_blob.byte_size
      attachment.destroy
      total_size -= byte_size
    end
  end

  private

  def get_total_size
    ActiveStorage::Blob
      .joins(:attachments)
      .where(active_storage_attachments: { name: "album_zip", record_type: "Show" })
      .sum(:byte_size)
  end
end
