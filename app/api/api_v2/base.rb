class ApiV2::Base < Grape::API
  format :json

  # Helpers
  # helpers ApiV2::Helpers::AuthHelper
  helpers ApiV2::Helpers::SharedHelpers
  helpers ApiV2::Helpers::SharedParams

  # Endpoints
  # before { authenticate_api_key! unless swagger_endpoint? }

  # Error handling
  rescue_from ActiveRecord::RecordNotFound do |e|
    error!({ message: "Not found" }, 404)
  end
  rescue_from ActiveRecord::RecordNotUnique do |e|
    error!({ message: "Not unique" }, 409)
  end
  rescue_from ActiveRecord::RecordInvalid do |e|
    errors = e.record.errors.full_messages.join(", ")
    error!({ message: "Record invalid: #{errors}" }, 422)
  end
end
