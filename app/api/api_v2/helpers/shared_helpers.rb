module ApiV2::Helpers::SharedHelpers
  extend Grape::API::Helpers

  def apply_sorting(relation, sort_options)
    attribute, direction = params[:sort].split(":")
    direction ||= "asc"
    if sort_options.include?(attribute) && [ "asc", "desc" ].include?(direction)
      relation.order("#{attribute} #{direction}")
    else
      error!({ message: "Invalid sort parameter" }, 400)
    end
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
end
