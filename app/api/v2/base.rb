require_relative "shows"

class V2::Base < Grape::API
  # version "v2", using: :path
  format :json

  mount V2::Shows

  get '/foo' do
    binding.irb
  end

  add_swagger_documentation
end
