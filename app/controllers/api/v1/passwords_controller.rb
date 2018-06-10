# frozen_string_literal: true
class Api::V1::PasswordsController < DeviseController
  def create
    if user.present?
      user.send_reset_password_instructions
      render json: { success: true }
    else
      render json: {
        success: false,
        message: 'Email address not found'
      }
    end
  end

  private

  def user
    @user ||= User.where(email: params[:user][:email]).first
  end
end
