# frozen_string_literal: true
class ErasController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @shows = years.index_with { |year| shows_for_year(year) }
    render_xhr_without_layout
  end

  private

  def shows_for_year(year)
    shows = Show.includes(:venue)
    return shows.between_years('1983', '1987') if year == '1983-1987'
    shows.during_year(year)
  end

  def years
    ERAS.values.flatten
  end
end
