# frozen_string_literal: true
class Phishin::V2::Api < Grape::API
  version 'v2'

  mount Phishin::V2::Shows

  # include Phishin::V2::SwaggerDoc
end
