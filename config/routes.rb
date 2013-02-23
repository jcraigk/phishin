Phishin::Application.routes.draw do
    
    root :to => 'pages#index'
    
    # Main browse pages
    match '/years' => 'pages#years'
    match '/songs' => 'pages#songs'
    match '/cities' => 'pages#cities'
    match '/venues' => 'pages#venues'
    match '/liked' => 'pages#liked'
    
    # Catch-all matcher for short URLs
    match '/(:glob(/:glob2(/:glob3)))' => 'pages#glob'
    
end
