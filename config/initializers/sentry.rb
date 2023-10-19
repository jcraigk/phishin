Sentry.init do |config|
  config.dsn = ENV.fetch('SENTRY_DSN', nil)
end
