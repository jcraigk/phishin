module ApiV2::Helpers::AuthHelper
  def authenticate_api_key!
    error!("Unauthorized: No API key provided", 401) if key_from_header.blank?
    error!("Unauthorized: Invalid API key", 401) unless api_key
  end

  def swagger_endpoint?
    request.path.include?("/swagger_doc")
  end

  private

  def key_from_header
    @key_from_header ||= headers["Authorization"]&.sub("Bearer ", "")
  end

  def api_key
    @api_key ||= ApiKey.active.find_by(key: key_from_header)
  end
end
