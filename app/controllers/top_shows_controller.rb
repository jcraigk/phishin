# frozen_string_literal: true
class TopShowsController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @shows =
      Show.avail
          .where('likes_count > 0')
          .includes(:venue, show_tags: :tag)
          .order(likes_count: :desc, date: :desc)
          .limit(40)
    @shows_likes = user_likes_for_shows(@shows)
    render_xhr_without_layout
  end
end
