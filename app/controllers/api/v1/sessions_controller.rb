# frozen_string_literal: true
class Api::V1::SessionsController < DeviseController
  prepend_before_action :require_no_authentication, only: [:create]
  before_action :authenticate_user_from_token!, only: [:destroy]

  respond_to :json

  def create
    ensure_params_exist
    self.resource = resource_class.new
    resource = User.find_for_database_authentication(email: params[:user][:email])
    return invalid_login_attempt unless resource

    if resource.valid_password?(params[:user][:password])
      sign_in('user', resource)
      resource.generate_authentication_token!
      render json: { success: true, auth_token: resource.authentication_token, email: resource.email }
      return
    end
    invalid_login_attempt
  end

  def destroy
    sign_out(resource_name)
    current_user.generate_authentication_token!
    render json: { success: true }
  end

  protected

  def ensure_params_exist
    return unless params[:user][:email].blank? or params[:user][:password].blank?
    render json: { success: false, message: "Missing user[email] or user[password] parameter" }, status: 422
  end

  def invalid_login_attempt
    warden.custom_failure!
    render json: { success: false, message: "Email or password incorrect" }, status: 401
  end

  private

  # https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
  def authenticate_user_from_token!
    user_email  = params[:user][:email].presence
    user        = user_email && User.find_by_email(user_email)

    if user && Devise.secure_compare(user.authentication_token, params[:user][:auth_token])
      sign_in('user', user)
    else
      render json: { success: false, message: 'Invalid email or auth_token' }
    end
  end
end
