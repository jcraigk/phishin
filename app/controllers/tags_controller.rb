# frozen_string_literal: true
class TagsController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL
  caches_action :show, expires_in: CACHE_TTL

  def index
    @tags = Tag.order(tags_order_by).all
    render layout: false if request.xhr?
  end

  def selected_tag
    @tag = Tag.where('lower(name) = ?', params[:name].downcase).first
    if @tag.nil?
      view = 'tag_not_found'
    else
      view = 'show'
      @mode = params[:entity]
      @mode = 'show' unless %w[show track].include?(@mode)

      case @mode
      when 'show'
        tag_ids = ShowTag.where(tag_id: @tag.id).map(&:show_id)
        @shows = Show.where(id: tag_ids)
                     .includes(:venue, :tags)
                     .order(shows_order_by)
                     .paginate(page: params[:page], per_page: 20)
        @shows_likes = @shows.map { |show| get_user_show_like(show) }
        @entities = @shows
      when 'track'
        tag_ids = TrackTag.where(tag_id: @tag.id).map(&:track_id)
        @tracks = Track.where(id: tag_ids)
                       .includes(:show, :tags)
                       .order(tracks_order_by)
                       .paginate(page: params[:page], per_page: 20)
        @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
        @entities = @tracks
      end
    end

    request.xhr? ? (render view, layout: false) : (render view)
  end

  private

  def tags_order_by
    params[:sort] = 'name' unless %w(name shows_count tracks_count).include?(params[:sort])

    case params[:sort]
    when 'name'
      'name asc'
    when 'shows_count'
      'shows_count desc, name asc'
    when 'tracks_count'
      'tracks_count desc, name asc'
    end
  end

  def shows_order_by
    params[:sort] = 'date desc' unless ['date desc', 'date', 'likes', 'duration'].include?(params[:sort])

    case params[:sort]
    when 'date desc'
      'date desc'
    when 'date'
      'date asc'
    when 'likes'
      'likes_count desc'
    when 'duration'
      'duration desc'
    end
  end

  def tracks_order_by
    params[:sort] = 'date desc' unless ['date desc', 'date', 'likes', 'duration'].include?(params[:sort])

    case params[:sort]
    when 'date desc'
      'shows.date desc'
    when 'date'
      'shows.date asc'
    when 'likes'
      'likes_count desc'
    when 'duration'
      'duration desc'
    end
  end
end
