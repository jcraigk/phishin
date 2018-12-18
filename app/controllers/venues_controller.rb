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
    if params[:sort] == 'name'
      { name: :asc }
    elsif params[:sort] == 'performances'
      { shows_count: :desc, name: :asc }
    end
  end
end
