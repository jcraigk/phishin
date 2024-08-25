module ApiHelper
  def auth_header
    api_key = create(:api_key)
    { 'Authorization' => "Bearer #{api_key.key}" }
  end

  def get_authorized(path, params: {}, headers: {})
    api_key = ApiKey.create!(name: "Test Key", email: "test@example.com")
    headers["Authorization"] = "Bearer #{api_key.key}"
    get path, params:, headers:
  end

  def post_authorized(path, params: {}, headers: {})
    api_key = ApiKey.create!(name: "Test Key", email: "test@example.com")
    headers["Authorization"] = "Bearer #{api_key.key}"
    post path, params:, headers:
  end
end
