Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allows requests from any origin
    origins '*'

    # Allows any header and the specified methods
    resource '*',
             headers: :any,
             methods: [:get, :post, :patch, :put, :delete, :options, :head],
             max_age: 600
  end
end
