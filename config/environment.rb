# frozen_string_literal: true
require_relative 'application'
Rails.application.initialize!

Rails.application.configure do
  config.action_mailer.smtp_settings = {
    user_name: ENV.fetch('SMTP_USERNAME', nil),
    password: ENV.fetch('SMTP_PASSWORD', nil),
    address: ENV.fetch('SMTP_ADDRESS', nil),
    port: 587,
    authentication: :plain
  }
end
