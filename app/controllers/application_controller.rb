class ApplicationController < ActionController::Base
  include ApplicationHelper
  protect_from_forgery

  before_action :random_song_with_excerpt

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def self.caches_action_params(action, params = [])
    params += %i[sort per_page page id slug]
    caches_action action, cache_path: proc { |c| c.params.permit(*params) }
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
    render_view("errors/404", 404)
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
    char = params[:char]
    params[:char] = char.in?(App.first_char_list) ? char : App.first_char_list.first
  end
end
