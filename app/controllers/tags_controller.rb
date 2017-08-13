class TagsController < ApplicationController
  caches_action :index, cache_path: proc { |c| c.request.url }, expires_in: CACHE_TTL
  caches_action :show,  cache_path: proc { |c| c.request.url }, expires_in: CACHE_TTL

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
      params[:entity] = 'show' unless %w(show track).include? params[:entity]

      case params[:entity]
        when 'show'
          tag_ids = ShowTag.where(tag_id: @tag.id).map(&:show_id)
          @shows = Show.where(id: tag_ids).includes(:venue, :tags).order(shows_order_by).paginate(page: params[:page], per_page: 20)
          @shows_likes = @shows.map {|show| get_user_show_like(show) }
          @entities = @shows
        when 'track'
          tag_ids = TrackTag.where(tag_id: @tag.id).map(&:track_id)
          @tracks = Track.where(id: tag_ids).includes(:show, :tags).order(tracks_order_by).paginate(page: params[:page], per_page: 20)
          @tracks_likes = @tracks.map {|track| get_user_track_like(track) }
          @entities = @tracks
      end
    end

    request.xhr? ? (render view, layout: false) : (render view)
  end

  private

  def tags_order_by
    params[:sort] = 'name' unless ['name', 'shows_count', 'tracks_count'].include? params[:sort]
    case params[:sort]
      when 'name'
        order_by = "name asc"
      when 'shows_count'
        order_by = "shows_count desc, name asc"
      when 'tracks_count'
        order_by = "tracks_count desc, name asc"
    end
    order_by
  end

  def shows_order_by
    params[:sort] = 'date desc' unless ['date desc', 'date', 'likes', 'duration'].include?(params[:sort])
    order_by = ''
    case params[:sort]
      when 'date desc'
        order_by = 'date desc'
      when 'date'
        order_by = 'date asc'
      when 'likes'
        order_by = 'likes_count desc'
      when 'duration'
        order_by = 'duration desc'
    end
    order_by
  end

  def tracks_order_by
    params[:sort] = 'date desc' unless ['date desc', 'date', 'likes', 'duration'].include?(params[:sort])
    order_by = ''
    case params[:sort]
      when 'date desc'
        order_by = 'shows.date desc'
      when 'date'
        order_by = 'shows.date asc'
      when 'likes'
        order_by = 'likes_count desc'
      when 'duration'
        order_by = 'duration desc'
    end
    order_by
  end
end
