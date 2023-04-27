# frozen_string_literal: true
require 'grape-swagger'

class Phishin::V2::Api < Grape::API
  version 'v2'
  format :json

  mount Phishin::V2::Shows


  # rescue_from :all do |e|
  #   raise e
  #   error_response(message: "Internal server error: #{e}", status: 500)
  # end

  add_swagger_documentation(
    # host: 'https://phish.in',
    base_path: '/api',
    # schemes: Common::Helpers::ApiHelpers.swagger_scheme_config,
    schemes: %w[http https],
    info: {
      title: APP_NAME,
      description: APP_DESC,
      contact_name: 'Phishin Music',
      contact_email: 'phish.in.music@gmail.com',
      contact_url: 'https://phish.in/contact',
      license: 'MIT',
      license_url: 'https://github.com/jcraigk/phishin/blob/main/MIT-LICENSE',
      terms_of_service_url: 'https://github.com/jcraigk/phishin/blob/main/README.md',
    },
    array_use_braces: true,
    security_definitions: {
      bearer: {
        type: 'apiKey',
        name: 'Authorization',
        in: 'header',
        description: 'Provide API Key with `Bearer: ` prefix, e.g. "Bearer abcde12345"'
      }
    }
  )
end
