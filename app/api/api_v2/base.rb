class ApiV2::Base < Grape::API
  format :json

  # Helpers
  helpers ApiV2::Helpers::AuthHelper
  helpers ApiV2::Helpers::SharedHelpers
  helpers ApiV2::Helpers::SharedParams

  # Endpoints
  before { authenticate_api_key! unless swagger_endpoint? }
  mount ApiV2::Announcements
  mount ApiV2::Auth
  mount ApiV2::Likes
  mount ApiV2::Playlists
  mount ApiV2::Search
  mount ApiV2::Shows
  mount ApiV2::Songs
  mount ApiV2::Tags
  mount ApiV2::Tours
  mount ApiV2::Venues
  mount ApiV2::Years

  # Error handling
  rescue_from ActiveRecord::RecordNotFound do |e|
    error!({ message: "Not found" }, 404)
  end
  rescue_from ActiveRecord::RecordNotUnique do |e|
    error!({ message: "Not unique" }, 409)
  end
  rescue_from ActiveRecord::RecordInvalid do |e|
    errors = e.record.errors.full_messages.join(", ")
    error!({ message: "Record invalid: #{errors}" }, 422)
  end

  # Swagger docs
  add_swagger_documentation \
    info: {
      title: "#{App.app_name} API v2",
      description:
        "A RESTful API for accessing content on #{App.app_name}, an " \
          "open source archive of live Phish audience recordings",
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
        description: "Announcements about new content and site updates"
      },
      {
        name: "auth",
        description: "Manage user authentication including registration, login, and password reset"
      },
      {
        name: "playlists",
        description: "Playlists created by users"
      },
      {
        name: "search",
        description: "Search across shows, songs, venues, tours, and tags"
      },
      {
        name: "songs",
        description: "Songs that Phish have played, including audio tracks of live performances"
      },
      {
        name: "tags",
        description: "Tags conveying metadata about shows and audio tracks"
      },
      {
        name: "tours",
        description: "Tours that Phish have embarked on, including associated shows"
      },
      {
        name: "venues",
        description: "Venues that Phish have played at, including associated shows"
      },
      {
        name: "years",
        description: "Years and eras during which Phish have performed live shows"
      },
      {
        name: "shows",
        description: "Live shows performed by Phish, including audio tracks"
      }
    ]
end
