# frozen_string_literal: true
class Api::V1::YearsController < Api::V1::ApiController
  caches_action_params :index, %i[include_show_counts]
  caches_action_params :show

  def index
    respond_with_success(requested_year_data)
  end

  def show
    return respond_with_success(shows_that_year) if requested_years
    respond_with_404
  end

  private

  def requested_year_data
    params[:include_show_counts] ? eras_with_show_counts : year_list
  end

  def eras_with_show_counts
    year_list.each_with_object([]) do |era, list|
      list << {
        date: era,
        show_count: shows_for_era(era).count
      }
    end
  end

  def year_list
    ERAS.values.flatten
  end

  def shows_for_era(era)
    return Show.published.during_year(era) unless era == '1983-1987'
    Show.published.between_years('1983', '1987')
  end

  def shows_that_year
    @shows_that_year =
      Show.published.between_years(*requested_years)
          .includes(:venue, :tags, tracks: %i[songs tags])
          .order(date: :asc)
  end

  def requested_years
    @requested_years = years_from_range || years_from_single
  end

  def years_from_single
    return unless params[:id].match?(/\A\d{4}\z/)
    [params[:id], params[:id]]
  end

  def years_from_range
    return unless params[:id] =~ /\A(\d{4})-(\d+{4})\z/
    [Regexp.last_match[1], Regexp.last_match[2]]
  end
end
