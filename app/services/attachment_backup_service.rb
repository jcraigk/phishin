class AttachmentBackupService < ApplicationService
  extend Dry::Initializer

  BATCH_SIZE = 100

  param :model_name, proc(&:to_s)
  param :attachment_name, proc(&:to_s)

  def call
    model_class = model_name.constantize

    log_info("Starting backup of #{model_name}.#{attachment_name}")

    log_info("Collecting existing S3 keys...")
    existing_keys = collect_existing_s3_keys
    log_info("Found #{existing_keys.size} existing keys in S3")

    total_count = count_attachments(model_class)
    log_info("Found #{total_count} #{model_name} records with #{attachment_name} to process")

    processed_count, uploaded_count, skipped_count, errored_count = backup_attachments(model_class, existing_keys)

    log_info("Backup completed: processed #{processed_count} records, uploaded #{uploaded_count} files, skipped #{skipped_count} existing files, #{errored_count} errors")
    true
  end

  private

  def collect_existing_s3_keys
    existing_keys = Set.new
    next_token = nil

    begin
      loop do
        response = s3_client.list_objects_v2(
          bucket: s3_bucket_name,
          continuation_token: next_token
        )

        response.contents.each do |object|
          # Extract the base key from the partitioned path
          parts = object.key.split("/")
          existing_keys << parts.last if parts.size == 3
        end

        next_token = response.next_continuation_token
        break unless next_token
      end
    rescue => e
      log_error("Error listing S3 objects: #{e.message}")
      return Set.new
    end

    existing_keys
  end

  def count_attachments(model_class)
    attachment_count = 0
    model_class.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each do |record|
        begin
          attachment = record.send(attachment_name)
          attachment_count += 1 if attachment.attached?
        rescue => e
          # Ignore errors when counting
        end
      end
    end
    attachment_count
  end

  def backup_attachments(model_class, existing_keys)
    processed_count = 0
    uploaded_count = 0
    skipped_count = 0
    errored_count = 0

    model_class.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch_processed = 0
      batch_uploaded = 0
      batch_skipped = 0
      batch_errored = 0

      batch.each do |record|
        # Skip to next record if this attachment isn't attached
        unless record.respond_to?(attachment_name) && record.send(attachment_name).attached?
          next
        end

        # Process the attachment
        begin
          attachment = record.send(attachment_name)

          if attachment.is_a?(ActiveStorage::Attached::One)
            # Process has_one_attached
            uploaded, skipped, errored = process_blob(attachment.blob, record.id, existing_keys)
          else
            # Process has_many_attached
            uploaded = skipped = errored = 0
            attachment.each do |a|
              u, s, e = process_blob(a.blob, record.id, existing_keys)
              uploaded += u
              skipped += s
              errored += e
            end
          end

          batch_processed += 1 if uploaded > 0 || skipped > 0 || errored > 0
          batch_uploaded += uploaded
          batch_skipped += skipped
          batch_errored += errored
        rescue => e
          log_error("Error processing attachment for #{model_name} ##{record.id}: #{e.message}")
          batch_errored += 1
        end
      end

      processed_count += batch_processed
      uploaded_count += batch_uploaded
      skipped_count += batch_skipped
      errored_count += batch_errored

      log_info("Progress: #{processed_count} processed, #{uploaded_count} uploaded, #{skipped_count} skipped, #{errored_count} errors")
    end

    [ processed_count, uploaded_count, skipped_count, errored_count ]
  end

  def process_blob(blob, record_id, existing_keys)
    return [ 0, 0, 1 ] unless blob && blob.key.present?

    # Skip if already in S3
    return [ 0, 1, 0 ] if blob.service_name.to_sym == :amazon

    begin
      s3_key = blob.key

      # Check if key exists in our pre-fetched set
      if existing_keys.include?(s3_key)
        log_info("Skipped (already exists): #{blob.filename} (#{s3_key})")
        return [ 0, 1, 0 ]
      end

      # Try to download the blob
      begin
        # Download the file
        io = StringIO.new(blob.download)

        # Construct the partitioned key path
        partitioned_key = "#{s3_key[0..1]}/#{s3_key[2..3]}/#{s3_key}"

        # Upload directly to S3 using AWS SDK instead of ActiveStorage service
        s3_client.put_object(
          bucket: s3_bucket_name,
          key: partitioned_key,
          body: io,
          content_type: blob.content_type
        )

        log_info("Uploaded: #{blob.filename} (#{partitioned_key}) for #{model_name} ##{record_id}")
        [ 1, 0, 0 ]
      rescue => e
        log_info("File not found (skipped): #{s3_key} for #{model_name} ##{record_id} - #{e.message}")
        [ 0, 0, 1 ]
      end
    rescue => e
      log_info("Error processing blob: #{s3_key} - #{e.message}")
      [ 0, 0, 1 ]
    end
  end

  def s3_client
    @s3_client ||=
      Aws::S3::Client.new(
        region: ENV.fetch("AWS_REGION", "us-east-1"),
        access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
      )
  end

  def s3_bucket_name
    @s3_bucket_name ||= ENV.fetch("AWS_BUCKET")
  end

  def log_info(message)
    puts "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
    Rails.logger.info(message)
  end

  def log_error(message)
    puts "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
    Rails.logger.error(message)
  end
end
