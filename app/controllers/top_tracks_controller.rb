# frozen_string_literal: true
class TopTracksController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @tracks =
      Track.where('likes_count > 0')
           .includes(:show, :tags)
           .order(likes_count: :desc, title: :asc)
           .limit(40)
    @tracks_likes = user_likes_for_tracks(@tracks)
    @tracks_likes = []
    render_xhr_without_layout
  end
end
