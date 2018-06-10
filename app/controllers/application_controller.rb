# frozen_string_literal: true
class ApplicationController < ActionController::Base
  include ApplicationHelper
  protect_from_forgery

  # before_action :artificial_wait if Rails.env.development?
  before_action :random_lyrical_excerpt
  before_action :init_session
  before_action :init_params
  before_action :require_xhr

  protected

  def random_lyrical_excerpt
    return unless request.xhr?
    @random_song = Song.random_lyrical_excerpt
  end

  def require_xhr!
    return if request.xhr?
    redirect_to(:root, alert: "You're doing it wrong (XHR required)")
  end

  def get_user_track_like(track)
    return unless track&.likes && current_user
    track.likes.where(user_id: current_user.id).first
  end

  def get_user_show_like(show)
    return unless show && current_user
    show.likes.where(user_id: current_user.id).first
  end

  def render_xhr_without_layout
    render layout: false if request.xhr?
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
