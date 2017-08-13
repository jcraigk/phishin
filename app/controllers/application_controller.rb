class ApplicationController < ActionController::Base
  include ApplicationHelper
  protect_from_forgery

  # before_filter :artificial_wait if Rails.env == "development"
  before_filter :random_lyrical_excerpt # Pull lyrical excerpt unless XHR request
  # before_filter :authenticate_by_htpasswd
  before_filter :init_session
  before_filter :init_params
  before_filter :require_xhr

  def random_lyrical_excerpt
    @random_song = Song.random_lyrical_excerpt.first unless request.xhr?
  end

  def require_xhr!
    return if request.xhr?
    redirect_to(:root, alert: "You're doing it wrong (XHR required)")
  end

  def is_user_signed_in
    render json: { success: user_signed_in?, msg: 'Hello' }
  end

  def get_user_track_like(track)
    return unless track && track.likes && current_user
    track.likes.where(user_id: current_user.id).first
  end

  protected

  def get_user_show_like(show)
    return unless show && current_user
    show.likes.where(user_id: current_user.id).first
  end

  private

  def authenticate_by_htpasswd
    return unless Rails.env == 'production'
    authenticate_or_request_with_http_basic do |username, password|
      username == HTAUTH_USERNAME && password == HTAUTH_PASSWORD
    end
  end

  def artificial_wait
    sleep 1.second
  end

  def init_session
    session[:playlist]            ||= []
    session[:playlist_shuffled]   ||= []
    session[:playlist_id]         ||= 0
    session[:playlist_name]       ||= ''
    session[:playlist_slug]       ||= ''
    session[:playlist_user_id]    ||= ''
    session[:playlist_username]   ||= ''
    session[:loop]                ||= false
    session[:shuffle]             ||= false
  end

  def init_params
    params[:t] ||= 0
  end

  def require_xhr
    return if request.xhr? || xhr_exempt_controller
    render 'layouts/application', layout: false
  end
end
