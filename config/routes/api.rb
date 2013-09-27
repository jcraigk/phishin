Phishin::Application.routes.draw do
  
  namespace :api do
    namespace :v1 do
      
      resources :tours,   only: [:index, :show]
      resources :years,   only: [:index, :show]
      resources :venues,  only: [:index, :show]
      resources :shows,   only: [:index, :show]
      resources :tracks,  only: [:index, :show]
      resources :songs,   only: [:index, :show]
      
    end
  end
end