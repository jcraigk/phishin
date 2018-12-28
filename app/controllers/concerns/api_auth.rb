# frozen_string_literal: true
module ApiAuth
  def require_auth
    return missing_key unless provided_key
    return invalid_key unless api_key
  end

  def save_api_request
    return false unless api_key
    ApiRequest.create(api_key: api_key, path: request.fullpath)
  end

  private

  def api_key
    ApiKey.active.find_by(key: provided_key)
  end

  def provided_key
    @provided_key ||=
      authenticate_or_request_with_http_token do |token, options|
        token
      end
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
