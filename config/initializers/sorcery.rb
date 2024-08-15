Rails.application.config.sorcery.submodules = %i[
  external
  remember_me
  reset_password
  user_activation
]

Rails.application.config.sorcery.configure do |config|
  config.external_providers = %i[google]

  # Google
  config.google.key = ENV.fetch("OAUTH_GOOGLE_KEY", nil)
  config.google.secret = ENV.fetch("OAUTH_GOOGLE_SECRET", nil)
  config.google.callback_url = "#{APP_BASE_URL}/oauth/callback/google"
  config.google.user_info_mapping = { email: "email" }
  config.google.scope = "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"

  config.cookie_domain = ENV.fetch("WEB_HOST", "localhost")

  # General auth settings
  config.user_class = "User"
  config.user_config do |user|
    user.stretches = 1 if Rails.env.test?
    user.remember_me_token_persist_globally = true
    user.user_activation_mailer = UserMailer
    user.email_delivery_method = :deliver_now
    user.activation_needed_email_method_name = :verification_required
    user.activation_success_email_method_name = nil
    user.reset_password_mailer = UserMailer
    user.reset_password_email_method_name = :reset_password
    user.authentications_class = Authentication
  end
end
