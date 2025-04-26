module Backup
  class ListingService < BaseService
    def call
      log_info("Collecting existing S3 keys...")
      existing_keys = collect_existing_s3_keys
      log_info("Found #{existing_keys.size} existing keys in S3")
      existing_keys
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
  end
end
