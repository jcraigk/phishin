# frozen_string_literal: true
class Api::V1::UsersController < Api::V1::ApiController
  def show
    return respond_with_success(user.username) if user.present?
    respond_with_failure 'Username not found'
  end

  private

  def user
    @user ||= User.where(username: params[:username]).first
  end
end
