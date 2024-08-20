class UserMailer < ApplicationMailer
  def reset_password(user)
    @user = user
    @url = "#{APP_BASE_URL}/password_resets/#{user.reset_password_token}/edit"
    mail to: user.email, subject: t("auth.password_reset")
  end
end
