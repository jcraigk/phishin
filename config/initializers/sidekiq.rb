Sidekiq.default_job_options = { backtrace: true }

redis_url = "redis://#{ENV.fetch('IN_DOCKER', false) ? 'redis' : 'localhost'}:6379"
redis_config = { url: ENV.fetch("REDIS_URL", redis_url) }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Disable annoying connection messages
Sidekiq.logger.level = Logger::WARN
