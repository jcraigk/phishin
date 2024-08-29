module ApiV2::Helpers::SharedHelpers
  extend Grape::API::Helpers

  def apply_sort(relation)
    attribute, direction = params[:sort].split(":")
    relation.order("#{relation.table_name}.#{attribute} #{direction}")
  end

  def current_user
    return unless (token = headers["X-Auth-Token"])
    decoded_token = JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    )
    user_id = decoded_token[0]["sub"]
    User.find_by(id: user_id)
  rescue JWT::DecodeError
    nil
  end

  def authenticate!
    error!({ message: "Unauthorized" }, 401) unless current_user
  end

  def log_api_event
    SwetrixEventJob.perform_async \
      request.url,
      request.user_agent,
      request.ip

    PlausibleEventJob.perform_async \
      request.url,
      request.user_agent,
      request.ip,
      @api_key&.id
  end
end
