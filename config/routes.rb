require "sidekiq/web"

Rails.application.routes.draw do
  # Health check
  get "/health", to: proc { [ 200, {}, [ "OK" ] ] }

  # Sidekiq admin
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])
    ) & ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"])
    )
  end
  mount Sidekiq::Web, at: "/sidekiq"

  # RSS
  get "feeds/rss", to: "feeds#rss", format: "xml", as: :rss_feed

  # MCP / AI Connectors
  post "/mcp(/:client)",
    to: "mcp#handle",
    defaults: { client: "default" },
    constraints: { client: Regexp.union((Server::VALID_CLIENTS - [ :default ]).map(&:to_s)) }
  get "/.well-known/openai-apps-challenge",
    to: proc { [ 200, {}, [ ENV.fetch("OPENAI_VERIFICATION_TOKEN", "") ] ] }

  # Authentication
  namespace :oauth do
    get "callback/:provider", to: "sorcery#callback"
    get ":provider", to: "sorcery#login", as: :at_provider
  end

  # File attachments / downloads
  get "/download-track/:id" => "downloads#download_track"
  get "/blob/:key" => "downloads#download_blob"

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

  # React harness
  root to: "application#application"
  get "/(:path(/:arg))", to: "application#application"
end
