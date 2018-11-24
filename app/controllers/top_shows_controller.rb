# frozen_string_literal: true
class TopShowsController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @shows =
      Show.avail
          .where('likes_count > 0')
          .includes(:venue, :tags)
          .order(likes_count: :desc, date: :desc)
          .limit(40)
    # @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @shows_likes = []
    render_xhr_without_layout
  end
end
