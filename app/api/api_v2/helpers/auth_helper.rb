module ApiV2::Helpers::AuthHelper
  def authenticate_api_key!
    error!("Unauthorized: No API key provided", 401) if api_key.blank?
    error!("Unauthorized: Invalid API key", 401) unless valid_api_key?
  end

  def swagger_endpoint?
    request.path.include?("/swagger_doc")
  end

  private

  def api_key
    @api_key ||= headers["Authorization"]&.sub("Bearer ", "")
  end

  def valid_api_key?
    ApiKey.active.exists?(key: api_key)
  end
end