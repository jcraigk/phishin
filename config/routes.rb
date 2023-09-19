# frozen_string_literal: true
Rails.application.routes.draw do
  root to: 'eras#index'

  # RSS feed
  get 'feeds/rss', to: 'feeds#rss', format: 'xml', as: :rss_feed

  # Stub audio file requests when testing
  get '/audio/*mp3', to: 'static_pages#faq' if Rails.env.test?

  # Users
  devise_for :users
  get '/my-shows' => 'my#my_shows', as: 'my_shows'
  get '/my-tracks' => 'my#my_tracks', as: 'my_tracks'

  # Static pages
  get '/faq' => 'static_pages#faq', as: 'faq'
  get '/contact-info' => 'static_pages#contact_info', as: 'contact_info'
  get '/api-docs' => 'static_pages#api_docs', as: 'api_docs'
  get '/tagin-project' => 'static_pages#tagin_project', as: 'tagin_project'

  # Reports
  get '/missing-content' => 'reports#missing_content', as: 'missing_content'

  # Content navigation pages
  get '/years' => 'eras#index', as: 'eras'
  get '/songs' => 'songs#index', as: 'songs'
  get '/map' => 'map#index', as: 'map'
  get '/venues' => 'venues#index', as: 'venues'
  get '/top-shows' => 'top_shows#index', as: 'top_shows'
  get '/top-tracks' => 'top_tracks#index', as: 'top_tracks'
  get '/search' => 'search#results', as: 'search'
  resources :tags, only: %i[index show]

  # Map
  get '/search-map' => 'map#search', as: 'map_search'

  # Likes
  post '/toggle-like' => 'likes#toggle_like', as: 'toggle_like'

  # Playlists / player
  get '/playlist' => 'playlists#active', as: 'active_playlist'
  get '/play/:slug' => 'playlists#active', as: 'activate_playlist'
  get '/playlists'  => 'playlists#stored', as: 'stored_playlists'
  get '/load-playlist' => 'playlists#load'
  post '/save-playlist' => 'playlists#save'
  post '/bookmark-playlist' => 'playlists#bookmark'
  post '/unbookmark-playlist' => 'playlists#unbookmark'
  post '/delete-playlist' => 'playlists#destroy'
  post '/reset-playlist' => 'playlists#reset'
  post '/override-playlist' => 'playlists#override'
  post '/reposition-playlist' => 'playlists#reposition'
  post '/add-track' => 'playlists#add_track'
  post '/add-show' => 'playlists#add_show'
  get '/next-track(/:track_id)' => 'playlists#next_track_id'
  get '/previous-track/:track_id' => 'playlists#previous_track_id'
  post '/submit-playback-loop' => 'playlists#submit_playback_loop'
  post '/submit-playback-shuffle' => 'playlists#submit_playback_shuffle'
  get '/random-show' => 'playlists#random_show'
  get '/random-song-track/:song_id' => 'playlists#random_song_track'

  # Track info/download
  get '/track-info/:track_id' => 'downloads#track_info', as: 'track_info'
  get '/play-track/:track_id' => 'downloads#play_track', as: 'play_track'
  get '/download-track/:track_id' => 'downloads#download_track', as: 'download_track'

  # Catch-all matcher for ambiguous content slugs
  get '/(:slug(/:anchor))' => 'ambiguity#resolve', constraints: { glob: %r{[^/]+} }

  # API Routes
  namespace :api do
    namespace :v1 do
      devise_for :users

      resources :eras,      only: %i[index show]
      resources :years,     only: %i[index show]
      resources :tours,     only: %i[index show]
      resources :venues,    only: %i[index show]
      resources :shows,     only: %i[index show]
      resources :tracks,    only: %i[index show]
      resources :songs,     only: %i[index show]
      resources :tags,      only: %i[index show]
      resources :playlists, only: %i[show]

      # Misc
      get 'search/:term',              to: 'search#index'
      get 'show-on-date/:date',        to: 'shows#on_date'
      get 'shows-on-day-of-year/:day', to: 'shows#on_day_of_year'
      get 'random-show',               to: 'shows#random'
    end
  end
end
