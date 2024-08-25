module Api
  module V2
  end
end

require_relative "years"
require_relative "shows"

class Api::V2::Base < Grape::API
  format :json

  mount Api::V2::Years
  mount Api::V2::Shows
  # mount Api::V2::Tracks
  # mount Api::V2::Venues
  # mount Api::V2::Songs

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
      terms_of_service_url: "https://phish.in/terms",
    }
end
