class AlbumZipCleanupJob
  include Sidekiq::Worker

  def perform
    return if total_size <= App.album_zip_disk_limit

    # Continue deleting the oldest blobs until we are under the disk limit
    while total_size > App.album_zip_disk_limit
      oldest_blob = ActiveStorage::Blob
        .joins(:attachments)
        .where(active_storage_attachments: { name: "album_zip", record_type: "Show" })
        .order(:created_at)
        .first
      break unless oldest_blob
      oldest_blob.purge
      total_size -= oldest_blob.byte_size
    end
  end

  private

  def total_size
    @total_size ||=
      ActiveStorage::Blob
        .joins(:attachments)
        .where(active_storage_attachments: { name: "album_zip", record_type: "Show" })
        .sum(:byte_size)
  end
end
