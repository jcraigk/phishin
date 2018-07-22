# frozen_string_literal: true
Rails.application.routes.draw do
  root to: 'content#years'

  # Users
  devise_for :users
  get '/user-signed-in' => 'application#user_signed_in'
  get '/my-shows' => 'my#my_shows', as: 'my_shows'
  get '/my-tracks' => 'my#my_tracks', as: 'my_tracks'

  # Static pages
  get '/legal-stuff' => 'pages#legal_stuff', as: 'legal_stuff'
  get '/contact-us' => 'pages#contact_us', as: 'contact_us'
  get '/api-docs' => 'pages#api_docs', as: 'api_docs'

  # Error pages
  get '/browser-unsupported' => 'errors#browser_unsupported', as: 'browser_unsupported'

  # Content navigation pages
  get '/years' => 'content#years', as: 'years'
  get '/songs' => 'content#songs', as: 'songs'
  get '/map' => 'content#map', as: 'map'
  get '/venues' => 'content#venues', as: 'venues'
  get '/top-shows' => 'content#top_liked_shows', as: 'top_shows'
  get '/top-tracks' => 'content#top_liked_tracks', as: 'top_tracks'
  get '/search' => 'search#results', as: 'search'
  get '/tags' => 'tags#index', as: 'tags'
  get '/tags/:name' => 'tags#selected_tag', as: 'tag'

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

  # Downloads
  get '/track-info/:track_id' => 'downloads#track_info', as: 'track_info'
  get '/play-track/:track_id' => 'downloads#play_track', as: 'play_track'
  get '/download-track/:track_id' => 'downloads#download_track', as: 'download_track'
  get '/download-show/:date' => 'downloads#request_download_show', as: 'download_show'
  get '/download/:md5' => 'downloads#download_album', as: 'download_album'

  # Catch-all matcher for short content URLs
  get '/(:glob(/:anchor))' => 'content#glob', constraints: { glob: %r{[^\/]+} }

  ##############################################
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
      resources :playlists, only: %i[show]

      namespace :playlists do
        get    'details'

        # Auth required
        get    'user_playlists'
        post   'save'
        delete 'destroy'
        get    'user_bookmarks'
        post   'bookmark'
        post   'unbookmark'
      end

      namespace :likes do
        get  'top_shows'
        get  'top_tracks'

        # Auth required
        get  'user_likes'
        post 'like'
        post 'unlike'
      end

      # Misc
      get 'search/:term',              to: 'search#index'
      get 'show-on-date/:date',        to: 'shows#on_date'
      get 'shows-on-day-of-year/:day', to: 'shows#on_day_of_year'
      get 'random-show',               to: 'shows#random'
      get 'users/:username',           to: 'users#show'
    end
  end
end
