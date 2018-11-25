# frozen_string_literal: true
class ErasController < ApplicationController
  caches_action :index, expires_in: CACHE_TTL

  def index
    @shows = years.each_with_object({}) do |year, shows|
      shows[year] = shows_for_year(year)
    end
    render_xhr_without_layout
  end

  private

  def shows_for_year(year)
    shows = Show.avail.includes(:venue)
    return shows.between_years('1983', '1987') if year == '1983-1987'
    shows.during_year(year)
  end

  def years
    ERAS.values.flatten
  end
end
