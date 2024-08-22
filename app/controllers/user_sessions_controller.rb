class UserSessionsController < ApplicationController
  def new
    return redirect_to root_path if current_user
    @user = User.new
  end

  def create
    if valid_credentials?
      auto_login(@user, true)
      redirect_back_or_to root_path, notice: t("auth.login_success")
    else
      redirect_to new_user_session_path, alert: t("auth.login_fail")
    end
  end

  def destroy
    logout
    redirect_to login_path, notice: t("auth.logout_success")
  end

  private

  def valid_credentials?
    @user = User.find_by(email: params[:email])
    @user&.valid_password?(params[:password])
  end
end
