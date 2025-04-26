# lib/tasks/backup.rake
namespace :backup do
  desc "Backup all configured model attachments to S3"
  task all: :environment do
    puts "Collecting existing S3 keys..."
    existing_keys = Backup::ListingService.call

    Rails.application.config.attachment_backup[:attachments].each do |config|
      model = config[:model]
      attachment = config[:attachment]

      puts "Backing up #{model} #{attachment}..."
      Backup::Service.call(model, attachment, existing_keys)
    end
  end

  desc "Backup specific model attachment to S3"
  task attachment: :environment do
    model = ENV["MODEL"]
    attachment = ENV["ATTACHMENT"]

    if model.blank? || attachment.blank?
      puts "ERROR: MODEL and ATTACHMENT environment variables are required"
      puts "Example: rake backup:attachment MODEL=Show ATTACHMENT=cover_art"
      exit 1
    end

    puts "Backing up #{model} #{attachment}..."
    Backup::Service.call(model, attachment)
  end

  desc "Clean up orphaned files in S3 storage"
  task cleanup: :environment do
    puts "Starting cleanup of orphaned files..."
    cleaned = Backup::CleanupService.call
    puts "Cleanup completed: removed #{cleaned} orphaned files"
  end
end
