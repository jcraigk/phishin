Phishin::Application.routes.draw do
  
  namespace :api do
    namespace :v1 do
      devise_for :users

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
      get 'shows-on-day-of-year/:day',      to: 'shows#on_day_of_year'
      get 'random-show',                    to: 'shows#random'
      
      get 'users/:username',                to: 'users#show'
      get 'users/:username/playlists',      to: 'users#playlists'
    end
  end
end