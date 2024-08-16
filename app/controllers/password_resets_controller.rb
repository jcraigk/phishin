class PasswordResetsController < ApplicationController
  before_action :load_user_from_token, only: :update
  # skip_before_action :require_login

  def new; end

  def edit
    @user = User.load_from_reset_password_token(params[:id])
    @token = params[:id]
    not_authenticated unless @user
  end

  def create
    @user = User.find_by(email: params[:email])
    @user&.deliver_reset_password_instructions!

    redirect_to new_password_reset_path, notice: t("auth.password_reset_sent")
  end

  def update
    return not_authenticated if (user = load_user_from_token).blank?
    if passwords_match? && user.change_password(params[:user][:password])
      auto_login(user, true)
      redirect_to root_path, notice: t("auth.update_password_success")
    else
      redirect_to edit_password_reset_path(user.reset_password_token),
                  notice: t("auth.update_password_fail")
    end
  end

  private

  def passwords_match?
    params[:user][:password] == params[:user][:password_confirmation]
  end

  def load_user_from_token
    @token = params[:user][:token]
    @user = User.load_from_reset_password_token(@token)
  end
end
