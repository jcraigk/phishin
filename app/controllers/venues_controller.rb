class VenuesController < ApplicationController
  caches_action_params :index

  def index
    @canonical_url = venues_url
    @venues = Venue.name_starting_with(char_param).order(order_by)
    render_view
  end

  private

  def order_by
    params[:sort] = "name" unless params[:sort].in?(%w[name performances])
    case params[:sort]
    when "name" then { name: :asc }
    when "performances" then { shows_count: :desc, name: :asc }
    end
  end
end
