class MyController < ApplicationController
  
  def my_shows
    if current_user
      show_ids = Like.where(likable_type: 'Show', user_id: current_user.id).all.map(&:id)
      @shows = Show.where(id: show_ids).order('date desc').paginate(page: params[:page], per_page: 20)
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    render layout: false if request.xhr?
  end
  
  def my_tracks
    if current_user
      track_ids = Like.where(likable_type: 'Track', user_id: current_user.id).all.map(&:id)
      @tracks = Track.where(id: track_ids).order('title asc').paginate(page: params[:page], per_page: 20)
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    end
    render layout: false if request.xhr?
  end
  
end