Sidekiq.default_job_options = { backtrace: true }

redis_url = "redis://#{ENV.fetch('IN_DOCKER', false) ? 'redis' : 'localhost'}:6379"
redis_config = { url: ENV.fetch("REDIS_URL", redis_url) }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Disable connection message on rspec runs and rake tasks in prod
if Rails.env.test? || Rails.env.production?
  Sidekiq.logger.level = Logger::WARN
end
