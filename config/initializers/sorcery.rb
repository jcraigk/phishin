Rails.application.config.sorcery.submodules = %i[
  external
  remember_me
  reset_password
]

Rails.application.config.sorcery.configure do |config|
  config.external_providers = %i[google]

  # Google
  config.google.key = ENV.fetch("OAUTH_GOOGLE_KEY", nil)
  config.google.secret = ENV.fetch("OAUTH_GOOGLE_SECRET", nil)
  config.google.callback_url = "#{APP_BASE_URL}/oauth/callback/google"
  config.google.user_info_mapping = { email: "email" }
  config.google.scope = "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"

  # Cookies
  config.cookie_domain = ENV.fetch("WEB_HOST", "localhost")

  # Users
  config.user_class = "User"
  config.user_config do |user|
    user.stretches = 1 if Rails.env.test?
    user.remember_me_token_persist_globally = true
    user.email_delivery_method = :deliver_now
    user.reset_password_mailer = UserMailer
    user.reset_password_email_method_name = :reset_password
    user.authentications_class = Authentication
  end
end
