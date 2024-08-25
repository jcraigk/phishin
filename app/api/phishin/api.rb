require_relative "shows"

class Phishin::Api < Grape::API
  # version "v2", using: :path
  format :json

  mount Phishin::Shows

  get '/foo' do
    binding.irb
  end

  add_swagger_documentation
end
