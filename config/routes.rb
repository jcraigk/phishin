Phishin::Application.routes.draw do
  
  root :to => 'content#index'

  # User stuff
  devise_for :users
  get '/user-signed-in' => 'application#is_user_signed_in'

  # Resque server
  mount Resque::Server, at: "/resque"

  # Static pages
  get     '/legal-stuff'    => 'pages#legal_stuff', as: 'legal_stuff'
  get     '/contact-us'     => 'pages#contact_us', as: 'contact_us'
    
  # Content pages
  get     '/years'          => 'content#years', as: 'years'
  get     '/songs'          => 'content#songs', as: 'songs'
  get     '/cities'         => 'content#cities', as: 'cities'
  get     '/venues'         => 'content#venues', as: 'venues'
  get     '/likes'          => 'content#likes', as: 'likes'
  
  # Likes
  post    '/toggle-like'    => 'likes#toggle_like', as: 'toggle_like'
  
  # Playlists / player
  get     '/playlist'                     => 'playlists#playlist', as: 'playlist'
  post    '/reset-playlist/'              => 'playlists#reset_playlist'
  post    '/update-current-playlist'      => 'playlists#update_current_playlist'
  post    '/add-track'                    => 'playlists#add_track_to_playlist'
  get     '/track-info/:track_id'         => 'playlists#track_info'
  get     '/next-track/:track_id'         => 'playlists#next_track_id'
  get     '/previous-track/:track_id'     => 'playlists#previous_track_id'
  
  # Downloads
  get     '/download-track/:track_id'     => 'downloads#download_track', as: 'download_track'
  get     '/download-show/:date'          => 'downloads#request_download_show', as: 'download_show'
  get     '/download/:md5'                => 'downloads#download_album', as: 'download_album'
  
  # Playlists
  # resources :playlists do
  #   member do
  #     get 'download'
  #   end
  # end
  
  # Catch-all matcher for short content URLs
  get     '/(:glob(/:glob2(/:glob3)))' => 'content#glob'
    
end
