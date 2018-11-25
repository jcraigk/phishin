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

  def user_likes_for_tracks(tracks)
    return [] unless current_user && tracks
    likes = Like.where(user: current_user, likable: tracks)
    tracks.map do |t|
      (like = likes.find { |l| l.likable == t }) ? like : nil
    end
  end

  def user_likes_for_shows(shows)
    return [] unless current_user && shows
    likes = Like.where(user: current_user, likable: shows)
    shows.map do |s|
      (like = likes.find { |l| l.likable == s }) ? like : nil
    end
  end

  def render_xhr_without_layout
    render layout: false if request.xhr?
  end

  def char_param
    c = params[:char]
    params[:char] = c.in?(FIRST_CHAR_LIST) ? c : FIRST_CHAR_LIST.first
  end

  def validate_sorting_for_shows
    params[:sort] = 'date desc' unless params[:sort].in?(['date desc', 'date asc', 'likes', 'duration'])
    @order_by =
      if params[:sort].in?(['date asc', 'date desc'])
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
