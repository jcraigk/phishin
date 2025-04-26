module Backup
  class CleanupService < BaseService
    BATCH_SIZE = 100

    def call
      log_info("Collecting valid attachment keys...")
      valid_keys = collect_valid_attachment_keys
      log_info("Found #{valid_keys.size} valid attachment keys")

      log_info("Listing S3 objects...")
      s3_objects = []
      total_objects = 0
      batch_count = 0

      begin
        next_token = nil

        loop do
          response = s3_client.list_objects_v2(
            bucket: s3_bucket_name,
            continuation_token: next_token
          )

          batch_objects = response.contents
          s3_objects += batch_objects
          total_objects += batch_objects.size
          batch_count += 1

          if batch_count % 10 == 0
            log_info("Listed #{total_objects} objects so far...")
          end

          next_token = response.next_continuation_token
          break unless next_token
        end
      rescue => e
        log_error("Error listing S3 objects: #{e.message}")
        return 0
      end

      log_info("Found #{s3_objects.size} total objects in S3")

      log_info("Checking objects against valid keys...")
      deleted_count = 0

      s3_objects.each do |object|
        key = object.key

        parts = key.split("/")
        prefix1, prefix2, base_key = parts

        unless base_key && base_key.length >= 4
          log_info("Deleting invalid file: #{key} (invalid key format)")
          if delete_s3_object(object.key)
            deleted_count += 1
          end
          next
        end

        expected_prefix1 = base_key[0..1]
        expected_prefix2 = base_key[2..3]

        if prefix1 != expected_prefix1 || prefix2 != expected_prefix2
          log_info("Deleting misplaced file: #{key} (should be in #{expected_prefix1}/#{expected_prefix2}/)")
          if delete_s3_object(object.key)
            deleted_count += 1
          end
          next
        end

        unless valid_keys.include?(base_key)
          log_info("Deleting orphaned file: #{key}")
          if delete_s3_object(object.key)
            deleted_count += 1
          end
        end
      end

      log_info("Deleted #{deleted_count} files")
      deleted_count
    end

    private

    def collect_valid_attachment_keys
      valid_keys = Set.new
      total_models = Rails.configuration.attachment_backup[:attachments].size
      current_model = 0

      Rails.configuration.attachment_backup[:attachments].each do |config|
        current_model += 1
        model_class = config[:model].constantize
        attachment_name = config[:attachment]

        log_info("Processing #{model_class}.#{attachment_name} (#{current_model}/#{total_models})")
        record_count = model_class.count
        log_info("Found #{record_count} total records")

        processed_count = 0
        model_class.find_in_batches(batch_size: BATCH_SIZE) do |batch|
          batch.each do |record|
            next unless record.respond_to?(attachment_name)

            begin
              attachment = record.send(attachment_name)
              next unless attachment.attached?

              if attachment.is_a?(ActiveStorage::Attached::One)
                valid_keys << attachment.blob.key if attachment.blob && attachment.blob.key.present?
              else
                attachment.each do |a|
                  valid_keys << a.blob.key if a.blob && a.blob.key.present?
                end
              end
            rescue => e
              # Skip this record on error
            end
          end

          processed_count += batch.size
          print "."
          if processed_count % 1000 == 0
            puts " #{processed_count}/#{record_count}"
          end
        end
        puts " #{processed_count}/#{record_count}"

        log_info("Completed #{model_class}.#{attachment_name} - found #{valid_keys.size} valid keys so far")
      end

      valid_keys
    end

    def delete_s3_object(key)
      log_info("Attempting to delete S3 object: #{key} from bucket: #{s3_bucket_name}")
      begin
        s3_client.delete_object(bucket: s3_bucket_name, key: key)
        log_info("Successfully deleted S3 object: #{key}")
        true
      rescue => e
        log_error("Failed to delete S3 object #{key}: #{e.message}")
        false
      end
    end
  end
end
