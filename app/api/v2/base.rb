require_relative "shows"

module Api
  module V2
    class Base < Grape::API
      format :json

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
          terms_of_service_url: "https://phish.in/terms",
        }
    end
  end
end
