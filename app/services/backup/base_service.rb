module Backup
  class BaseService < ApplicationService
    extend Dry::Initializer

    protected

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
end
