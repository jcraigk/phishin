Phishin::Application.routes.draw do

  root :to => 'content#index'
  
  # User stuff
  devise_for :users
  get     '/user-signed-in' => 'application#is_user_signed_in'
  
  # Resque
  mount Resque::Server, :at => "/resque"

  # Static Pages
  get     '/legal-stuff' => 'pages#legal_stuff', as: 'legal_stuff'
  get     '/contact-us' => 'pages#contact_us', as: 'contact_us'
    
  # Content pages
  get     '/years' => 'content#years', as: 'years'
  get     '/songs' => 'content#songs', as: 'songs'
  get     '/cities' => 'content#cities', as: 'cities'
  get     '/venues' => 'content#venues', as: 'venues'
  get     '/likes' => 'content#likes', as: 'likes'
  get     '/playlist' => 'content#playlist', as: 'playlist'
  
  # Likes
  post    '/toggle-like' => 'likes#toggle_like', as: 'toggle_like'
  
  # Downloads
  get     '/download-track/:track_id' => 'downloads#download_track', as: 'download_track'
  get     '/download-show/:show_id' => 'downloads#download_show', as: 'download_show'
  
  # Playlists
  # resources :playlists do
  #   member do
  #     get 'download'
  #   end
  # end
  
  # Catch-all matcher for short content URLs
  get     '/(:glob(/:glob2(/:glob3)))' => 'content#glob'
    
end
