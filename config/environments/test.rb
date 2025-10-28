Rails.application.configure do
  config.action_controller.allow_forgery_protection = false
  config.action_controller.perform_caching = false
  config.action_dispatch.show_exceptions = false
  config.action_mailer.delivery_method = :test
  config.active_support.deprecation = :silence
  config.cache_store = :null_store
  config.consider_all_requests_local = true
  config.eager_load = false
  config.serve_static_assets = true
  config.static_cache_control = "public, max-age=3600"
  config.whiny_nils = true
  config.active_storage.service = :test
end
