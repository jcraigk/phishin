# frozen_string_literal: true
Phishin::Application.routes.draw do
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
