require "sidekiq/web"

Rails.application.routes.draw do
  # Health check
  get "/health", to: proc { [ 200, {}, [ "OK" ] ] }

  # Agent / bot discovery endpoints
  get "/sitemap.xml", to: "sitemap#show", as: :sitemap_xml, format: false
  get "/.well-known/mcp/server-card.json", to: "well_known#mcp_server_card"
  get "/.well-known/api-catalog", to: "well_known#api_catalog"
  get "/.well-known/agent-card.json", to: "well_known#a2a_agent_card"
  get "/.well-known/agent-skills/index.json", to: "well_known#agent_skills_index"

  # Sidekiq admin (cookie issued by POST /api/v2/admin/jobs/sidekiq_session)
  constraints SidekiqAdminConstraint.new do
    mount Sidekiq::Web, at: "/sidekiq"
  end
  match "/sidekiq(/*path)", to: proc { [ 404, { "Content-Type" => "text/plain" }, [ "Not Found" ] ] }, via: :all

  # RSS
  get "feeds/rss", to: "feeds#rss", format: "xml", as: :rss_feed

  # MCP / AI Connectors
  post "/mcp(/:client)",
    to: "mcp#handle",
    defaults: { client: "default" },
    constraints: { client: Regexp.union((Server::VALID_CLIENTS - [ :default ]).map(&:to_s)) }
  get "/.well-known/openai-apps-challenge",
    to: proc { [ 200, {}, [ ENV.fetch("OPENAI_VERIFICATION_TOKEN", "") ] ] }

  # MCP OAuth passthrough (satisfies client-side OAuth discovery for no-auth servers)
  get ".well-known/oauth-protected-resource/*path", to: "mcp_oauth#protected_resource"
  get ".well-known/oauth-protected-resource", to: "mcp_oauth#protected_resource"
  get ".well-known/oauth-authorization-server", to: "mcp_oauth#authorization_server"
  get "authorize", to: "mcp_oauth#authorize"
  post "register", to: "mcp_oauth#register"
  post "token", to: "mcp_oauth#token"

  # Authentication
  namespace :oauth do
    get "callback/:provider", to: "sorcery#callback"
    get ":provider", to: "sorcery#login", as: :at_provider
  end

  # File attachments / downloads
  get "/download-track/:id" => "downloads#download_track"
  get "/blob/:key" => "downloads#download_blob"
  post "/admin/direct_uploads", to: "admin/direct_uploads#create"
  post "/rails/active_storage/direct_uploads", to: proc { [ 404, {}, [] ] }

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

      get "search/:term",              to: "search#index", constraints: { term: /.+/ }
      get "show-on-date/:date",        to: "shows#on_date"
      get "shows-on-day-of-year/:day", to: "shows#on_day_of_year"
      get "random-show",               to: "shows#random"
    end
  end

  # API v2
  mount ApiV2::Api => "/api/v2"

  root to: "application#application"
  get "/admin/*path", to: "application#application"
  get "/(:path(/:arg))", to: "application#application"
end
