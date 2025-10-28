Sidekiq.default_job_options = { backtrace: true }

redis_url = "redis://#{ENV.fetch('IN_DOCKER', false) ? 'redis' : 'localhost'}:6379"
redis_config = { url: ENV.fetch("REDIS_URL", redis_url) }

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.death_handlers << ->(job, ex) do
    Sentry.capture_exception(
      ex,
      extra: {
        worker: job["class"],
        job_id: job["jid"],
        arguments: job["args"],
        queue: job["queue"],
        retry_count: job["retry_count"],
        failed_at: Time.now.iso8601
      }
    )
  end

  config.error_handlers << Proc.new do |ex, context|
    Sentry.capture_exception(
      ex,
      extra: {
        worker: context[:class],
        job_id: context[:jid],
        arguments: context[:args],
        queue: context[:queue],
        retry_count: context.dig(:job, "retry_count") || 0,
        failed_at: Time.now.iso8601
      }
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Disable spammy connection messages
Sidekiq.logger.level = Logger::WARN
