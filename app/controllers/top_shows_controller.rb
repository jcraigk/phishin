class TopShowsController < ApplicationController
  caches_action_params :index

  def index
    @shows =
      Show.published
          .where('likes_count > 0')
          .includes(:venue, show_tags: :tag)
          .order(likes_count: :desc, date: :desc)
          .limit(40)
    @shows_likes = user_likes_for_shows(@shows)
    render_xhr_without_layout
  end
end
