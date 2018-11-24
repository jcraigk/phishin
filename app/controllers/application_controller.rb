# frozen_string_literal: true
class ApplicationController < ActionController::Base
  include ApplicationHelper
  protect_from_forgery

  before_action :random_song_with_lyrical_excerpt
  before_action :init_session
  before_action :init_params
  before_action :require_xhr
  before_action :permitted_params, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  def slug
    params[:slug]
  end

  def user_signed_in
    render json: { success: user_signed_in? }
  end

  protected

  def render_404
    view = 'errors/404'
    request.xhr? ? render(view, layout: false) : render(view)
  end

  def permitted_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[username])
  end

  def random_song_with_lyrical_excerpt
    return unless request.xhr?
    @random_song = Song.random_with_lyrical_excerpt
  end

  def require_xhr!
    return if request.xhr?
    redirect_to(:root, alert: "You're doing it wrong (XHR required)")
  end

  def get_user_track_like(track)
    return unless track&.likes && current_user
    track.likes.find_by(user: current_user)
  end

  # TODO: clean this up - it's called in N+1 fashion
  def get_user_show_like(show)
    return unless show && current_user
    show.likes.find_by(user: current_user)
  end

  def render_xhr_without_layout
    render layout: false if request.xhr?
  end

  def char_param
    c = params[:char]
    params[:char] = c.in?(FIRST_CHAR_LIST) ? c : FIRST_CHAR_LIST.first
  end

  def validate_sorting_for_year_or_scope
    params[:sort] = 'date desc' unless params[:sort].in?(['date desc', 'date asc', 'likes', 'duration'])
    @order_by =
      if ['date asc', 'date desc'].include?(params[:sort])
        params[:sort]
      elsif params[:sort] == 'likes'
        'likes_count desc, date desc'
      elsif params[:sort] == 'duration'
        'shows.duration, date desc'
      end
  end

  private

  def artificial_wait
    sleep 1.second
  end

  def init_session
    session[:playlist] ||= []
    session[:playlist_shuffled] ||= []
    session[:playlist_id] ||= 0
    session[:playlist_name] ||= ''
    session[:playlist_slug] ||= ''
    session[:playlist_user_id] ||= ''
    session[:playlist_username] ||= ''
    session[:loop] ||= false
    session[:shuffle] ||= false
  end

  def init_params
    params[:t] ||= 0
  end

  def require_xhr
    return if request.xhr? || xhr_exempt_controller
    render 'layouts/application', layout: false
  end
end
