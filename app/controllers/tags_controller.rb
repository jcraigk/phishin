class TagsController < ApplicationController
  caches_action_params :index
  caches_action_params :show, %i[entity]

  def index
    @tag_groups = Tag.order(tags_order_by).group_by(&:group).sort
    render_view
  end

  def show
    case context
    when 'show'
      @shows = fetch_shows
      @shows_likes = user_likes_for_shows(@shows)
    when 'track'
      @tracks = fetch_tracks
      @tracks_likes = user_likes_for_tracks(@tracks)
    end

    render_view
  end

  private

  def context
    @context ||=
      if params[:entity].in?(%w[show track])
        params[:entity]
      elsif ShowTag.where(tag:).count.positive?
        'show'
      else
        'track'
      end
  end

  def tag
    @tag ||= Tag.friendly.find(params[:id])
  end

  def fetch_shows
    tag.shows
       .includes(:venue, :tags)
       .order(shows_order_by)
       .paginate(page: params[:page], per_page: params[:per_page].presence || 20)
  end

  def fetch_tracks
    tag.tracks
       .includes(:show, :tags)
       .order(tracks_order_by)
       .paginate(page: params[:page], per_page: params[:per_page].presence || 20)
  end

  def tags_order_by
    params[:sort] = 'name' unless
      params[:sort].in?(%w[name shows_count tracks_count])

    case params[:sort] # rubocop:disable Style/HashLikeCase
    when 'name'
      { name: :asc }
    when 'shows_count'
      { shows_count: :desc, name: :asc }
    when 'tracks_count'
      { tracks_count: :desc, name: :asc }
    end
  end

  def shows_order_by # rubocop:disable Metrics/MethodLength
    params[:sort] = 'date desc' unless
      params[:sort].in?(['date desc', 'date', 'likes', 'duration'])

    case params[:sort] # rubocop:disable Style/HashLikeCase
    when 'date desc'
      { date: :desc }
    when 'date'
      { date: :asc  }
    when 'likes'
      { likes_count: :desc }
    when 'duration'
      { duration: :desc }
    end
  end

  def tracks_order_by # rubocop:disable Metrics/MethodLength
    params[:sort] = 'date desc' unless
      ['date desc', 'date', 'likes', 'duration'].include?(params[:sort])

    case params[:sort]
    when 'date desc'
      'shows.date desc, tracks.position asc'
    when 'date'
      'shows.date asc, tracks.position asc'
    when 'likes'
      { likes_count: :desc }
    when 'duration'
      { duration: :desc }
    end
  end
end
