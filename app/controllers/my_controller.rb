class MyController < ApplicationController
  
  def my_shows
    validate_sorting_for_my_shows
    if current_user
      show_ids = Like.where(likable_type: 'Show', user_id: current_user.id).all.map(&:likable_id)
      @shows = Show.where(id: show_ids).includes(:tracks).order(@order_by).paginate(page: params[:page], per_page: 20)
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    render layout: false if request.xhr?
  end
  
  def my_tracks
    if current_user
      track_ids = Like.where(likable_type: 'Track', user_id: current_user.id).all.map(&:likable_id)
      @tracks = Track.where(id: track_ids).includes(:show).order('title asc').paginate(page: params[:page], per_page: 20)
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    end
    render layout: false if request.xhr?
  end
  
  private
  
  def validate_sorting_for_my_shows
    params[:sort] = 'date desc' unless ['date desc', 'date asc', 'title', 'likes', 'duration'].include? params[:sort]
    if params[:sort] == 'show.date asc' or params[:sort] == 'show.date desc'
      @order_by = params[:sort]
    elsif params[:sort] == 'title'
      @order_by = "title desc, show.date desc"
    elsif params[:sort] == 'likes'
      @order_by = "likes_count desc, show.date desc"
    elsif params[:sort] == 'duration'
      @order_by = "duration, show.date desc"
    end
  end
  
  def validate_sorting_for_my_tracks
    params[:sort] = 'date desc' unless ['date desc', 'date asc', 'likes', 'duration'].include? params[:sort]
    if params[:sort] == 'date asc' or params[:sort] == 'date desc'
      @order_by = params[:sort]
    elsif params[:sort] == 'likes'
      @order_by = "likes_count desc, date desc"
    elsif params[:sort] == 'duration'
      @order_by = "duration, date desc"
    end
  end
  
end