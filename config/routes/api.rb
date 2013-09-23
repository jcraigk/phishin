Phishin::Application.routes.draw do
  
  namespace :api do
    namespace :v1 do
      resources :venues, only: [:index, :show]
      resources :shows, only: [:index, :show] do
        member do
          get :tracks, to: 'shows#tracks'
        end
      end
      resources :songs, only: [:index, :show] do
        member do
          get :tracks, to: 'songs#tracks'
        end
      end
      resources :tracks, only: [:show] do
        member do
          get :songs, to: 'tracks#songs'
        end
      end
    end
  end
    
end