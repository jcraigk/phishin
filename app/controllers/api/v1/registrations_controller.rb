# frozen_string_literal: true
class Api::V1::RegistrationsController < DeviseController
  respond_to :json

  def create
    user = User.new(params[:user])
    if user.save
      user.generate_authentication_token!
      return render_success
    end

    render_failure
  end

  private

  def render_success
    render json:  {
      success: true,
      email: user.email,
      auth_token: user.authentication_token
    }, status: 201
  end

  def render_failure
    warden.custom_failure!
    render json: user.errors, status: 422
  end
end
