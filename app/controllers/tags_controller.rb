# frozen_string_literal: true
class TagsController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL
  caches_action :show, expires_in: CACHE_TTL

  def index
    @tags = Tag.order(tags_order_by)
    render_xhr_without_layout
  end

  def show
    case mode
    when 'show'
      @shows = fetch_shows
      @shows_likes = user_likes_for_shows(@shows)
    when 'track'
      @tracks = fetch_tracks
      @tracks_likes = user_likes_for_tracks(@tracks)
    end

    render_xhr_without_layout
  end

  private

  def mode
    @mode ||= params[:entity].in?(%w[show track]) ? params[:entity] : 'show'
  end

  def tag
    @tag ||= Tag.friendly.find(params[:id])
  end

  def fetch_shows
    tag.shows
       .includes(:venue, :tags)
       .order(shows_order_by)
       .paginate(page: params[:page], per_page: 20)
  end

  def fetch_tracks
    tag.tracks
       .includes(:show, :tags)
       .order(tracks_order_by)
       .paginate(page: params[:page], per_page: 20)
  end

  def tags_order_by
    params[:sort] = 'name' unless
      params[:sort].in?(%w[name shows_count tracks_count])

    case params[:sort]
    when 'name'
      { name: :asc }
    when 'shows_count'
      { shows_count: :desc, name: :asc }
    when 'tracks_count'
      { tracks_count: :desc, name: :asc }
    end
  end

  def shows_order_by
    params[:sort] = 'date desc' unless
      params[:sort].in?(['date desc', 'date', 'likes', 'duration'])

    case params[:sort]
    when 'date desc'
      { date: :desc }
    when 'date'
      { date: :asc }
    when 'likes'
      { likes_count: :desc }
    when 'duration'
      { duration: :desc }
    end
  end

  def tracks_order_by
    params[:sort] = 'date desc' unless
      ['date desc', 'date', 'likes', 'duration'].include?(params[:sort])

    case params[:sort]
    when 'date desc'
      'shows.date desc'
    when 'date'
      'shows.date asc'
    when 'likes'
      { likes_count: :desc }
    when 'duration'
      { duration: :desc }
    end
  end
end
