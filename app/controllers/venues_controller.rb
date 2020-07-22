# frozen_string_literal: true
class VenuesController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @venues = Venue.name_starting_with(char_param).order(order_by)
    render_xhr_without_layout
  end

  private

  def order_by
    params[:sort] = 'name' unless params[:sort].in?(%w[name performances])
    case params[:sort]
    when 'name' then { name: :asc }
    when 'performances' then { shows_count: :desc, name: :asc }
    end
  end
end
