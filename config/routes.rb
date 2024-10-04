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

  get "feeds/rss", to: "feeds#rss", format: "xml", as: :rss_feed

  namespace :oauth do
    get "callback/:provider", to: "sorcery#callback"
    get ":provider", to: "sorcery#login", as: :at_provider
  end

  get "/download-show/:date" => "downloads#download_show"
  get "/download-track/:id" => "downloads#download_track"

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

  mount ApiV2::Api => "/api/v2"

  root to: "application#application"
  get "/(:path(/:arg))", to: "application#application"

  # Test env: disable content file requests
  get "/audio/*mp3", to: "static_pages#faq" if Rails.env.test?
end
