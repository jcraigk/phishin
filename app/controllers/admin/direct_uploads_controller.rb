class Admin::DirectUploadsController < ActiveStorage::DirectUploadsController
  skip_forgery_protection
  before_action :require_admin!

  private

  def require_admin!
    user = user_from_token
    return head :unauthorized if user.nil?
    head :forbidden unless user.admin?
  end

  def user_from_token
    return unless (token = request.headers["X-Auth-Token"])
    decoded_token = JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    )
    User.find_by(id: decoded_token[0]["sub"])
  rescue JWT::DecodeError
    nil
  end
end
