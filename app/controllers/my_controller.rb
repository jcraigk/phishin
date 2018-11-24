# frozen_string_literal: true
class MyController < ApplicationController
  def my_shows
    return unless current_user
    validate_sorting_for_my_shows

    show_ids = Like.where(likable_type: 'Show', user: current_user).map(&:likable_id)
    @shows = Show.where(id: show_ids).includes(:tracks).order(@order_by).paginate(page: params[:page], per_page: 20)
    # @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @shows_likes = []

    render_xhr_without_layout
  end

  def my_tracks
    return unless current_user
    validate_sorting_for_my_tracks

    track_ids = Like.where(likable_type: 'Track', user: current_user).map(&:likable_id)
    @tracks = Track.where(id: track_ids).includes(:show).order(@order_by).paginate(page: params[:page], per_page: 20)
    # @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    @tracks_likes = []

    render_xhr_without_layout
  end

  private

  def validate_sorting_for_my_shows
    params[:sort] = 'date desc' unless ['date desc', 'date asc', 'title', 'likes', 'duration'].include?(params[:sort])
    @order_by =
      case params[:sort]
      when 'date asc', 'date desc'
        params[:sort]
      when 'title'
        'title desc, date desc'
      when 'likes'
        'likes_count desc, date desc'
      when 'duration'
        'duration, date desc'
      end
  end

  def validate_sorting_for_my_tracks
    params[:sort] = 'shows.date desc' unless ['title', 'shows.date desc', 'shows.date asc', 'likes', 'duration'].include?(params[:sort])
    @order_by =
      case params[:sort]
      when 'title'
        'title asc'
      when 'shows.date asc', 'shows.date desc'
        params[:sort]
      when 'likes'
        'likes_count desc'
      when 'duration'
        'duration'
      end
  end
end
