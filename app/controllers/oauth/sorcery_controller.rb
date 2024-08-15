class Oauth::SorceryController < ApplicationController
  skip_before_action :require_login, raise: false

  def oauth
    login_at(params[:provider])
  end

  def callback
    return redirect_to(root_path) if login_from(params[:provider])
    create_user_and_login
  rescue StandardError => e
    Sentry.capture_exception(e)
    redirect_to login_path, alert: t("auth.external_fail", provider: provider_title)
  end

  private

  def create_user_and_login
    binding.irb
    user = User.find_by(email: auth_hash[:info][:email])
    if user
      authentication =
        user.authentications
            .find_by(provider: params[:provider], uid: auth[:uid])

      unless authentication
        user.authentications
            .create!(provider: params[:provider], uid: auth[:uid])
      end
    else
      user = User.build_from(params[:provider])
      user.username = user.email.split("@").first
      user.save!
    end

    user.activate! unless user.verified?
    reset_session
    auto_login(user)

    redirect_back_or_to root_path
  end

  def auth_params
    params.permit(:code)
  end

  def provider_title
    params[:provider].titleize
  end
end
