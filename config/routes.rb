Phishin::Application.routes.draw do
  
  # mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  root :to => 'content#index'

  # User stuff
  devise_for :users
  get '/user-signed-in' => 'application#is_user_signed_in'

  # Resque server
  mount Resque::Server, at: "/resque"

  # Static pages
  get     '/legal-stuff'                  => 'pages#legal_stuff',                   as: 'legal_stuff'
  get     '/contact-us'                   => 'pages#contact_us',                    as: 'contact_us'

  # Error pages
  get     '/browser-unsupported'          => 'errors#browser_unsupported',          as: 'browser_unsupported'
  get     '/mobile-unsupported'           => 'errors#mobile_unsupported',           as: 'mobile_unsupported'

  # Reports
  get     '/missing-shows'                => 'reports#missing_shows',               as: 'missing_shows'
    
  # Content navigation pages
  get     '/years'                        => 'content#years',                       as: 'years'
  get     '/songs'                        => 'content#songs',                       as: 'songs'
  get     '/map'                          => 'content#map',                         as: 'map'
  get     '/venues'                       => 'content#venues',                      as: 'venues'
  get     '/top-shows'                    => 'content#top_liked_shows',             as: 'top_shows'
  get     '/top-tracks'                   => 'content#top_liked_tracks',            as: 'top_tracks'
  get     '/search'                       => 'search#results',                      as: 'search'

  # Map
  get     '/search-map'                   => 'map#search',                          as: 'map_search'

  # Likes
  post    '/toggle-like'                  => 'likes#toggle_like',                   as: 'toggle_like'
  
  # Playlists / player
  get     '/playlist'                     => 'playlists#active_playlist',           as: 'active_playlist'
  get     '/playlists'                    => 'playlists#saved_playlists',           as: 'saved_playlists'
  get     '/play/:slug'                   => 'playlists#playlist'
  get     '/get-playlist'                 => 'playlists#get_playlist'
  get     '/get-saved-playlists'          => 'playlists#get_saved_playlists'
  post    '/save-playlist'                => 'playlists#save_playlist'
  post    '/delete-playlist'              => 'playlists#delete_playlist'
  post    '/reset-playlist/'              => 'playlists#reset_playlist'
  post    '/clear-playlist/'              => 'playlists#clear_playlist'
  post    '/update-current-playlist'      => 'playlists#update_current_playlist'
  post    '/add-track'                    => 'playlists#add_track_to_playlist'
  post    '/add-show'                     => 'playlists#add_show_to_playlist'
  get     '/next-track(/:track_id)'       => 'playlists#next_track_id'
  get     '/previous-track/:track_id'     => 'playlists#previous_track_id'
  post    '/submit-playlist-options'      => 'playlists#submit_playlist_options'
  get     '/random-show'                  => 'playlists#random_show'
  
  # Downloads
  get     '/track-info/:track_id'         => 'downloads#track_info',                as: 'track_info'
  get     '/play-track/:track_id'         => 'downloads#play_track',                as: 'play_track'
  get     '/download-track/:track_id'     => 'downloads#download_track',            as: 'download_track'
  get     '/download-show/:date'          => 'downloads#request_download_show',     as: 'download_show'
  get     '/download/:md5'                => 'downloads#download_album',            as: 'download_album'
  
  # Catch-all matcher for short content URLs
  get     '/(:glob(/:anchor))' => 'content#glob'
    
end
