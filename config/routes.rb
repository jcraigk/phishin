# frozen_string_literal: true
Rails.application.routes.draw do
  root to: 'eras#index'

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
  get '/playlist' => 'playlists#active_playlist', as: 'active_playlist'
  get '/play/:slug' => 'playlists#active_playlist', as: 'activate_playlist'
  get '/playlists'  => 'playlists#saved_playlists', as: 'saved_playlists'
  get '/get-playlist' => 'playlists#playlist'
  post '/save-playlist' => 'playlists#save_playlist'
  post '/bookmark-playlist' => 'playlists#bookmark_playlist'
  post '/unbookmark-playlist' => 'playlists#unbookmark_playlist'
  post '/delete-playlist' => 'playlists#destroy_playlist'
  post '/reset-playlist/' => 'playlists#reset_playlist'
  post '/clear-playlist/' => 'playlists#clear_playlist'
  post '/update-current-playlist' => 'playlists#update_active_playlist'
  post '/add-track' => 'playlists#add_track_to_playlist'
  post '/add-show' => 'playlists#add_show_to_playlist'
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
  get '/(:slug(/:anchor))' => 'ambiguity#resolve', constraints: { glob: %r{[^\/]+} }

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
