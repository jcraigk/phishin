class ApplicationController < ActionController::Base
  include ApplicationHelper
  protect_from_forgery

  before_action :random_song_with_excerpt
  before_action :permitted_params, if: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def self.caches_action_params(action, params = [])
    params += %i[sort per_page page id slug]
    caches_action action,
                  cache_path: proc { |c| c.params.permit(*params) },
                  expires_in: CACHE_TTL
  end

  protected

  def render_view(view = nil, status = 200)
    if view
      return render view, layout: false if request.xhr?
      return render view, status:, formats: :html
    end
    render layout: false if request.xhr?
  end

  def render_not_found
    render_view('errors/404', 404)
  end

  def permitted_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[username])
  end

  def random_song_with_excerpt
    return if request.xhr?
    @random_song = Song.random_with_lyrical_excerpt
  end

  def user_likes_for_tracks(tracks)
    return [] unless current_user && tracks
    likes = Like.where(user: current_user, likable: tracks).includes(:likable)
    tracks.map do |t|
      (like = likes.find { |l| l.likable == t }) ? like : nil
    end
  end

  def user_likes_for_shows(shows)
    return [] unless current_user && shows
    likes = Like.where(user: current_user, likable: shows).includes(:likable)
    shows.map do |s|
      (like = likes.find { |l| l.likable == s }) ? like : nil
    end
  end

  def char_param
    c = params[:char]
    params[:char] = c.in?(FIRST_CHAR_LIST) ? c : FIRST_CHAR_LIST.first
  end
end
