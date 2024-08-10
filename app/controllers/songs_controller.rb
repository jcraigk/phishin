class SongsController < ApplicationController
  caches_action_params :index, %i[char sort]

  def index
    @songs = Song.title_starting_with(char_param).order(order_by)
    render_view
  end

  private

  def order_by
    params[:sort] = "title" unless params[:sort].in?(%w[title performances])
    case params[:sort]
    when "title" then { title: :asc }
    when "performances" then { tracks_count: :desc, title: :asc }
    end
  end
end
