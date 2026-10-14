class AttachmentBackupJob
  include Sidekiq::Job

  sidekiq_options retry: false

  def perform
    existing_keys = Backup::ListingService.call
    raise "S3 listing returned no keys; refusing to re-upload every attachment" if existing_keys.empty?

    Rails.configuration.attachment_backup[:attachments].each do |config|
      Backup::AttachmentService.call(config[:model], config[:attachment], existing_keys)
    end
  end
end
