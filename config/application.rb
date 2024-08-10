require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "active_record/railtie"

Bundler.require(*Rails.groups)

module Phishin
  class Application < Rails::Application
    config.load_defaults 7.2

    # For backwards compatibility with earlier Devise logins
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1
    # config.action_dispatch.cookies_serializer = :marshal # :json_allow_marshal

    config.hosts << ENV.fetch("WEB_HOST", nil) if ENV["WEB_HOST"].present?
  end
end
