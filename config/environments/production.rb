Rails.application.configure do
  config.action_controller.asset_host = App.base_url
  config.cache_store = :mem_cache_store, { expires_in: 10.minutes }
  config.action_controller.perform_caching = true
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
  config.eager_load = false
  config.force_ssl = true
  config.i18n.fallbacks = true
  config.require_master_key = true
end
