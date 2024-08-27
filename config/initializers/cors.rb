Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "*",
             headers: :any,
             methods: %i[ get post patch put delete options head ],
             max_age: 600
  end
end
