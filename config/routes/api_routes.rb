Phishin::Application.routes.draw do
  
  namespace :api do
    namespace :v1 do
      resources :shows, only: [:index, :show]
      resources :songs, only: [:index, :show]
      resources :venues, only: [:index, :show]
    end
  end
    
end