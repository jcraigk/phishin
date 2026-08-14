module ApiV2::Helpers::AdminHelper
  extend Grape::API::Helpers

  def authenticate_admin!
    error!({ message: "Unauthorized" }, 401) unless current_user
    error!({ message: "Forbidden" }, 403) unless current_user.admin?
  end
end
