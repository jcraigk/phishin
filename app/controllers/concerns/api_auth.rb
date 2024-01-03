module ApiAuth
  def require_auth
    return missing_key if key_from_header.blank?
    return invalid_key if active_api_key.blank?
    true
  end

  private

  def active_api_key
    ApiKey.active.find_by(key: key_from_header)
  end

  def key_from_header
    @key_from_header ||=
      (request.authorization || request.headers.to_h['Authorization']).to_s.sub('Bearer ', '')
  end

  def missing_key
    render json: {
      success: false,
      error: 'No API key provided'
    }, status: :unauthorized
  end

  def invalid_key
    render json: {
      succes: false,
      message: 'Invalid API key provided'
    }, status: :unauthorized
  end

  def auth_header
    @auth_header ||= request.headers.to_h['Authorization']
  end
end
