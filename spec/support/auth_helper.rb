# frozen_string_literal: true
module AuthHelper
  def auth_header
    api_key = create(:api_key)
    { 'Authorization' => "Bearer #{api_key.key}" }
  end
end
