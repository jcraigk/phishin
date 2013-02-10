Phishin::Application.routes.draw do
    
    root :to => 'pages#years'
    
    match '/years' => 'pages#years'
    match '/songs' => 'pages#songs'
    match '/cities' => 'pages#cities'
    match '/venues' => 'pages#venues'
    match '/liked' => 'pages#liked'
    
end
