class UserMailer < ApplicationMailer
  def reset_password(user)
    @user = user
    @url = "#{App.base_url}/reset-password/#{user.reset_password_token}"
    mail to: user.email, subject: t("auth.password_reset")
  end
end
