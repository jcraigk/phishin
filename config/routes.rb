require "sidekiq/web"

Rails.application.routes.draw do
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])
    ) & ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"])
    )
  end
  mount Sidekiq::Web, at: "/sidekiq"

  root to: "eras#index"

  # RSS feed
  get "feeds/rss", to: "feeds#rss", format: "xml", as: :rss_feed

  # Stub audio file requests when testing
  get "/audio/*mp3", to: "static_pages#faq" if Rails.env.test?

  # Users
  namespace :oauth do
    get "callback/:provider", to: "sorcery#callback"
    get ":provider", to: "sorcery#oauth", as: :at_provider
  end
  resources :users, only: %i[new create]
  resources :user_sessions, only: %i[new create destroy]
  resources :password_resets, only: %i[new create edit update]
  get "login", to: "user_sessions#new", as: :login
  delete "logout", to: "user_sessions#destroy", as: :logout

  # User favorites
  get "/my-shows" => "my#my_shows", as: "my_shows"
  get "/my-tracks" => "my#my_tracks", as: "my_tracks"

  # Static pages
  get "/faq" => "static_pages#faq", as: "faq"
  get "/privacy" => "static_pages#privacy_policy", as: "privacy_policy"
  get "/terms" => "static_pages#terms_of_service", as: "terms_of_service"
  get "/contact-info" => "static_pages#contact_info", as: "contact_info"
  get "/api-docs" => "static_pages#api_docs", as: "api_docs"
  get "/tagin-project" => "static_pages#tagin_project", as: "tagin_project"

  # Reports
  get "/missing-content" => "reports#missing_content", as: "missing_content"

  # Content navigation pages
  get "/years" => "eras#index", as: "eras"
  get "/songs" => "songs#index", as: "songs"
  get "/map" => "map#index", as: "map"
  get "/venues" => "venues#index", as: "venues"
  get "/top-shows" => "top_shows#index", as: "top_shows"
  get "/top-tracks" => "top_tracks#index", as: "top_tracks"
  get "/search" => "search#results", as: "search"
  resources :tags, only: %i[index show]

  # Map
  get "/search-map" => "map#search", as: "map_search"

  # Likes
  post "/toggle-like" => "likes#toggle_like", as: "toggle_like"

  # Playlists / player
  get "/playlist" => "playlists#active", as: "active_playlist"
  get "/play/:slug" => "playlists#active", as: "activate_playlist"
  get "/playlists"  => "playlists#stored", as: "stored_playlists"
  get "/load-playlist" => "playlists#load"
  post "/save-playlist" => "playlists#save"
  post "/bookmark-playlist" => "playlists#bookmark"
  post "/unbookmark-playlist" => "playlists#unbookmark"
  post "/delete-playlist" => "playlists#destroy"
  post "/clear-playlist" => "playlists#clear"
  post "/reposition-playlist" => "playlists#reposition"
  post "/add-track" => "playlists#add_track"
  post "/remove-track" => "playlists#remove_track"
  post "/add-show" => "playlists#add_show"
  post "/enqueue-tracks" => "playlists#enqueue_tracks"
  get "/next-track(/:track_id)" => "playlists#next_track_id"
  get "/previous-track/:track_id" => "playlists#previous_track_id"
  get "/random-song-track/:song_id" => "playlists#random_song_track"

  # Track info/download
  get "/track-info/:track_id" => "downloads#track_info", as: "track_info"
  get "/play-track/:track_id" => "downloads#play_track", as: "play_track"
  get "/download-track/:track_id" => "downloads#download_track", as: "download_track"

  # Catch-all matcher for ambiguous content slugs
  get "/(:slug(/:anchor))" => "ambiguity#resolve", constraints: { glob: %r{[^/]+} }

  # API v1
  namespace :api do
    namespace :v1 do
      resources :eras,      only: %i[index show]
      resources :years,     only: %i[index show]
      resources :tours,     only: %i[index show]
      resources :venues,    only: %i[index show]
      resources :shows,     only: %i[index show]
      resources :tracks,    only: %i[index show]
      resources :songs,     only: %i[index show]
      resources :tags,      only: %i[index show]
      resources :playlists, only: %i[show]

      get "search/:term",              to: "search#index"
      get "show-on-date/:date",        to: "shows#on_date"
      get "shows-on-day-of-year/:day", to: "shows#on_day_of_year"
      get "random-show",               to: "shows#random"
    end
  end

  # API v2
  mount ApiV2::Api => "/api/v2"
end
