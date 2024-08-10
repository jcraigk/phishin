class ErasController < ApplicationController
  caches_action_params :index

  def index
    @shows = years.index_with { |year| shows_for_year(year) }
    render_view
  end

  private

  def shows_for_year(year)
    shows = Show.published.includes(:venue)
    return shows.between_years("1983", "1987") if year == "1983-1987"
    shows.during_year(year)
  end

  def years
    ERAS.values.flatten
  end
end
