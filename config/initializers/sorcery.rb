Rails.application.config.sorcery.submodules = %i[
  external
  remember_me
  reset_password
]

Rails.application.config.sorcery.configure do |config|
  config.cookie_domain = App.web_host
  config.external_providers = %i[ google ]

  # Google OAuth
  config.google.key = App.oauth_google_key
  config.google.secret = App.oauth_google_secret
  config.google.callback_url = "#{App.base_url}/oauth/callback/google"
  config.google.user_info_mapping = { email: "email" }
  config.google.scope = "https://www.googleapis.com/auth/userinfo.email"

  # Rails User Config
  config.user_class = "User"
  config.user_config do |user|
    user.stretches = 1 if Rails.env.test?
    user.remember_me_token_persist_globally = true
    user.email_delivery_method = :deliver_later
    user.reset_password_mailer = UserMailer
    user.reset_password_email_method_name = :reset_password
    user.authentications_class = Authentication
  end
end
