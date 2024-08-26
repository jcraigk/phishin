class GrapeApi::Base < Grape::API
  format :json

  # Helpers
  helpers GrapeApi::Helpers::SharedParams
  helpers GrapeApi::Helpers::AuthHelper
  helpers GrapeApi::Helpers::SharedHelpers

  # Endpoints
  before { authenticate_api_key! unless swagger_endpoint? }
  mount GrapeApi::Shows
  mount GrapeApi::Songs
  mount GrapeApi::Tours
  mount GrapeApi::Venues
  mount GrapeApi::Years

  # Swagger docs
  add_swagger_documentation \
    info: {
      title: "#{App.app_name} API v2",
      description:
        "A RESTful API for accessing content on #{App.app_name}, an " \
          "open source archive of live Phish audience recordings.",
      contact_email: "phish.in.music@gmail.com",
      contact_url: "https://phish.in/contact-info",
      license: "MIT",
      license_url: "https://github.com/jcraigk/phishin/blob/main/MIT-LICENSE",
      terms_of_service_url: "https://phish.in/terms"
    },
    security_definitions: {
      api_key: {
        type: "apiKey",
        name: "Authorization",
        in: "header",
        description:
          "Use your API key as a Bearer token in the 'Authorization' " \
            "header. Example: 'Authorization: Bearer YOUR_API_KEY'"
      }
    },
    security: [ { api_key: [] } ],
    tags: [
      {
        name: "years",
        description: "Years during which Phish performed live shows."
      },
      {
        name: "shows",
        description: "Live shows performed by Phish, including metadata and links to MP3 audio."
      }
    ]
end
