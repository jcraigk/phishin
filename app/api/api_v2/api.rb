class ApiV2::Api < ApiV2::Base
  mount ApiV2::Announcements
  mount ApiV2::Auth
  mount ApiV2::Likes
  mount ApiV2::Playlists
  mount ApiV2::Search
  mount ApiV2::Shows
  mount ApiV2::Songs
  mount ApiV2::Tags
  mount ApiV2::Tracks
  mount ApiV2::Tours
  mount ApiV2::Venues
  mount ApiV2::Years

  add_swagger_documentation \
    info: {
      title: "#{App.app_name} API v2",
      description:
        "A RESTful API for accessing data and content on [Phish.in](#{App.base_url}), an " \
        "open source archive of live Phish audience recordings. " \
        "See [GitHub](https://github.com/jcraigk/phishin) for development and issue tracking. " \
        "Access is provided free of charge and without warranty. Please be nice.",
      # contact_email: "phish.in.music@gmail.com",
      # contact_url: "https://phish.in/contact-info",
      # license: "MIT",
      # license_url: "https://github.com/jcraigk/phishin/blob/main/MIT-LICENSE",
      # terms_of_service_url: "https://phish.in/terms"
    },
    # security_definitions: {
    #   api_key: {
    #     type: "apiKey",
    #     name: "Authorization",
    #     in: "header",
    #     description:
    #       "Use your API key as a Bearer token in the 'Authorization' " \
    #         "header. Example: 'Authorization: Bearer YOUR_API_KEY'"
    #   }
    # },
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
        name: "likes",
        description: "User likes (upvotes) on shows and tracks"
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
        name: "shows",
        description: "Live shows performed by Phish, including audio tracks"
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
        name: "tracks",
        description: "Tracks of legal audio recordings from live Phish shows"
      },
      {
        name: "venues",
        description: "Venues that Phish have played at, including associated shows"
      },
      {
        name: "years",
        description: "Years and eras during which Phish have performed live shows"
      }
    ]
end
