# frozen_string_literal: true
class ApplicationController < ActionController::Base
  include ApplicationHelper
  protect_from_forgery

  before_action :random_song_with_excerpt
  before_action :require_xhr
  before_action :permitted_params, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  protected

  def render_xhr_without_layout
    render layout: false if request.xhr?
  end

  def render_404
    render 'errors/404'
  end

  def permitted_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[username])
  end

  def random_song_with_excerpt
    return if request_is_ajax?
    @random_song = Song.random_with_lyrical_excerpt
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

  def request_is_ajax?
    request.xhr?
  end

  def require_xhr
    return if request.xhr? || xhr_exempt_controller
    render 'layouts/application', layout: false
  end
end
