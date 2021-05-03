# frozen_string_literal: true
class TopTracksController < ApplicationController
  caches_action_params :index

  def index
    @tracks =
      Track.where('likes_count > 0')
           .includes(:show, track_tags: :tag)
           .order(likes_count: :desc, title: :asc)
           .limit(40)
    @tracks_likes = user_likes_for_tracks(@tracks)
    render_xhr_without_layout
  end
end
