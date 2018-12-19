# frozen_string_literal: true
module ApiAuth
  def require_auth!
    return missing_key unless provided_key
    valid_key = ApiKey.active.find_by(key: provided_key)
    return invalid_key unless valid_key
  end

  private

  def provided_key
    return nil unless auth_header
    @provided_key ||= auth_header.sub('Bearer ', '')
  end

  def missing_key
    render json: {
      success: false,
      error: 'No API key provided'
    }, status: 401
  end

  def invalid_key
    render json: {
      succes: false,
      message: 'Invalid API key provided'
    }, status: 401
  end

  def auth_header
    @auth_header ||= request.headers.to_h['Authorization']
  end
end
