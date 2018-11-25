# frozen_string_literal: true
class SongsController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @songs =
      Song.relevant
          .title_starting_with(char_param)
          .order(order_by)
    render_xhr_without_layout
  end

  private

  def order_by
    params[:sort] = 'title' unless params[:sort].in?(%w[title performances])
    if params[:sort] == 'title'
      { title: :asc }
    elsif params[:sort] == 'performances'
      { tracks_count: :desc, title: :asc }
    end
  end
end
