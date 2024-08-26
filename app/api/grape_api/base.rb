class GrapeApi::Base < Grape::API
  format :json

  # Helpers
  helpers GrapeApi::Helpers::AuthHelper
  helpers GrapeApi::Helpers::SharedHelpers
  helpers GrapeApi::Helpers::SharedParams

  # Endpoints
  before { authenticate_api_key! unless swagger_endpoint? }
  mount GrapeApi::Announcements
  mount GrapeApi::Auth
  mount GrapeApi::Playlists
  mount GrapeApi::Search
  mount GrapeApi::Shows
  mount GrapeApi::Songs
  mount GrapeApi::Tags
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
        name: "announcements",
        description: "Announcements about new content and other updates."
      },
      {
        name: "auth",
        description: "Manage user authentication including registration, login, and password reset via email."
      },
      {
        name: "password_resets",
        description: "Reset a user's password via email."
      },
      {
        name: "playlists",
        description: "Playlists created by users."
      },
      {
        name: "search",
        description: "Search across Shows, Songs, Venues, Tours, and Tags."
      },
      {
        name: "songs",
        description: "Songs that Phish have played, including tracks of actual performances."
      },
      {
        name: "tags",
        description: "Tags conveying metadata on Shows and Tracks."
      },
      {
        name: "tours",
        description: "Tours that Phish have embarked on, including associated Shows."
      },
      {
        name: "venues",
        description: "Venues that Phish have played on, including associated Shows."
      },
      {
        name: "years",
        description: "Years and eras during which Phish performed live shows."
      },
      {
        name: "shows",
        description: "Live shows performed by Phish, including metadata and links to MP3 audio."
      }
    ]
end
