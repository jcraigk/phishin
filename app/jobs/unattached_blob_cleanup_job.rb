class UnattachedBlobCleanupJob
  include Sidekiq::Job

  RETENTION = 1.day

  def perform
    ActiveStorage::Blob.unattached
                       .where(created_at: ..RETENTION.ago)
                       .find_each(&:purge_later)
  end
end
