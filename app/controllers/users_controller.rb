class UsersController < ApplicationController
  def new
    return redirect_to root_path if current_user
    @user = User.new
  end

  def create
    unless passwords_match?
      return redirect_to new_user_path, alert: I18n.t("auth.passwords_dont_match")
    end

    @user = User.new(signup_params.except(:password_confirmation))
    if @user.save
      auto_login(@user, true)
      redirect_to root_path, notice: I18n.t("auth.signup_success")
    else
      render :new
    end
  end

  private

  def passwords_match?
    signup_params[:password] == signup_params[:password_confirmation]
  end

  def signup_params
    params.require(:user).permit \
      :username, :email, :password, :password_confirmation
  end
end
