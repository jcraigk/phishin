module ApiHelper
  def auth_header
    api_key = create(:api_key)
    { 'Authorization' => "Bearer #{api_key.key}" }
  end
end
