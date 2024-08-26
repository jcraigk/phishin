module Api
  module V2
  end
end

# TODO: There must be a better way
Dir[File.join(__dir__, "*.rb")].each { |file| require_relative file }
Dir[File.join(__dir__, "entities", "*.rb")].each { |file| require_relative file }

class Api::V2::Base < Grape::API
  format :json

  helpers ApiKeyHelper
  before do
    authenticate_api_key! unless swagger_endpoint?
  end

  mount Api::V2::Years
  mount Api::V2::Shows

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

  helpers do
    def swagger_endpoint?
      request.path.include?("/swagger_doc")
    end
  end
end
