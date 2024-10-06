class AlbumZipCleanupJob
  include Sidekiq::Worker

  TIMEFRAME = 30.days

  def perform
    cutoff_date = TIMEFRAME.ago

    ActiveStorage::Attachment
      .where(name: "album_zip", record_type: "Show")
      .joins(:blob)
      .where("active_storage_blobs.created_at < ?", cutoff_date)
      .find_each do |attachment|
        attachment.purge
      end
  end
end
