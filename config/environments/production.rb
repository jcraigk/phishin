Rails.application.configure do
  config.action_controller.asset_host = "https://phish.in"
  config.cache_store = :mem_cache_store
  config.action_controller.perform_caching = true
  config.action_mailer.default_url_options = { host: ENV.fetch("WEB_HOST", nil) }
  config.action_mailer.smtp_settings = {
    user_name: ENV.fetch("SMTP_USERNAME", nil),
    password: ENV.fetch("SMTP_PASSWORD", nil),
    address: ENV.fetch("SMTP_ADDRESS", nil),
    port: 587,
    authentication: :plain
  }
  config.active_record.dump_schema_after_migration = false
  config.active_support.report_deprecations = false
  config.cache_classes = true
  config.consider_all_requests_local = false
  config.eager_load = true
  # config.force_ssl = true
  config.assume_ssl = true
  config.i18n.fallbacks = true
  config.require_master_key = true
end
