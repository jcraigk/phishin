Phishin::Application.routes.draw do
    
  devise_for :users

  root :to => 'content#index'
    
  # General Pages
  get '/legal-stuff' => 'pages#legal_stuff', as: 'legal_stuff'
  get '/contact-us' => 'pages#contact_us', as: 'contact_us'
    
  # Content pages
  get '/years' => 'content#years', as: 'years'
  get '/songs' => 'content#songs', as: 'songs'
  get '/cities' => 'content#cities', as: 'cities'
  get '/venues' => 'content#venues', as: 'venues'
  get '/liked' => 'content#liked', as: 'liked'
  get '/playlist' => 'content#playlist', as: 'playlist'

  # Catch-all matcher for short content URLs
  get '/(:glob(/:glob2(/:glob3)))' => 'content#glob'
    
end
