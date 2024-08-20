Rails.application.configure do
  config.action_controller.asset_host = "https://jcktest.ngrok.io"
  config.action_controller.perform_caching = false
  config.action_dispatch.best_standards_support = :builtin
  config.action_mailer.default_url_options = { host: "localhost:3000" }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.smtp_settings = {
    user_name: ENV.fetch("SMTP_USERNAME", nil),
    password: ENV.fetch("SMTP_PASSWORD", nil),
    address: ENV.fetch("SMTP_ADDRESS", nil),
    port: 587,
    authentication: :plain
  }
  config.active_support.deprecation = :log
  config.cache_classes = false
  config.consider_all_requests_local = true
  config.eager_load = false
  config.whiny_nils = true

  # Bullet gem (N+1 queries)
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
end
