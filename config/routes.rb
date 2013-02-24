Phishin::Application.routes.draw do
    
    root :to => 'content#index'
    
    # General Pages
    get '/legal-stuff' => 'pages#legal_stuff', as: 'legal_stuff'
    get '/contact-us' => 'pages#contact_us', as: 'contact_us'
    
    # Content pages
    get '/years' => 'content#years'
    get '/songs' => 'content#songs'
    get '/cities' => 'content#cities'
    get '/venues' => 'content#venues'
    get '/liked' => 'content#liked'
    get '/playlist' => 'content#playlist', as: 'playlist'

    # Catch-all matcher for short content URLs
    get '/(:glob(/:glob2(/:glob3)))' => 'content#glob'
    
end
