Phishin::Application.routes.draw do
  
  namespace :api do
    namespace :v1 do
      
      resources :eras,        only: [:index, :show]
      resources :years,       only: [:index, :show]
      resources :tours,       only: [:index, :show]
      resources :venues,      only: [:index, :show]
      resources :shows,       only: [:index, :show]
      resources :tracks,      only: [:index, :show]
      resources :songs,       only: [:index, :show]
      resources :playlists,   only: [:show]
      
      get 'search/:term',                   to: 'search#index'
      get 'show-on-date/:date',             to: 'shows#on_date'
      get 'random-show',                    to: 'shows#random'
      
    end
  end
end