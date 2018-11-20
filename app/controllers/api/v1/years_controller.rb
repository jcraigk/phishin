# frozen_string_literal: true
class Api::V1::YearsController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    respond_with_success(all_eras_with_show_counts)
  end

  def show
    return respond_with_success(shows_that_year) if requested_years
    respond_with_failure('Invalid year or year range')
  end

  private

  def all_eras_with_show_counts
    ERAS.values
        .flatten
        .each_with_object([]) do |era, response|
      response << {
        date: era,
        show_count: shows_for_era(era).count
      }
    end
  end

  def shows_for_era(era)
    return Show.avail.during_year(era) unless era == '1983-1987'
    Show.avail.between_years('1983', '1987')
  end

  def shows_that_year
    @shows_that_year =
      Show.avail
          .between_years(*requested_years)
          .includes(:venue)
          .order(date: :asc)
  end

  def requested_years
    @requested_years =
      if params[:id] =~ /\A(\d{4})-(\d+{4})\z/
        [Regexp.last_match[1], Regexp.last_match[2]]
      elsif params[:id].match?(/\A\d{4}\z/)
        [params[:id], params[:id]]
      end
  end
end
