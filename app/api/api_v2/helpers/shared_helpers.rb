module ApiV2::Helpers::SharedHelpers
  extend Grape::API::Helpers

  def apply_sort(relation, secondary_col = nil, secondary_dir = :asc)
    attribute, direction = params[:sort].split(":")
    relation = relation.order("#{relation.table_name}.#{attribute} #{direction}")
    if secondary_col && attribute != secondary_col
      relation = relation.order("#{relation.table_name}.#{secondary_col} #{secondary_dir}")
    end
    relation
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
