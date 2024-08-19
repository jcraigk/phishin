class Oauth::SorceryController < ApplicationController
  def oauth
    login_at(params[:provider])
  end

  def callback
    return redirect_to(root_path, notice: t("auth.login_success")) if login_from(params[:provider])
    create_user_and_login
  rescue StandardError => e
    Sentry.capture_exception(e)
    redirect_to login_path, alert: t("auth.external_fail", provider: provider_title)
  end

  private

  def create_user_and_login
    user = build_from(params[:provider])
    username = user.email.split("@").first.gsub(/[^A-Za-z0-9_]/, "-")
    username = "#{username}-#{SecureRandom.hex(4)}" if User.where(username:).exists?
    user.username = username
    user.save!
    reset_session
    auto_login(user, true)
    redirect_back_or_to root_path, notice: t("auth.login_success")
  rescue ActiveRecord::RecordNotUnique
    redirect_to login_path, alert: t("auth.email_taken", provider: provider_title)
  end

  def auth_params
    params.permit(:code)
  end

  def provider_title
    params[:provider].titleize
  end
end
