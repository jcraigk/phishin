# frozen_string_literal: true
module Ambiguity::YearRange
  def slug_as_year_range
    return false if year_range_from_slug.blank?

    validate_sorting_for_shows
    hydrate_year_range_page

    raise ActiveRecord::RecordNotFound unless @shows.any?

    true
  end

  private

  def hydrate_year_range_page # rubocop:disable Metrics/MethodLength
    @shows = shows_during_year_range
    @sections =
      @shows.group_by(&:tour_name)
            .each_with_object({}) do |(tour, shows), sections|
              sections[tour] = {
                shows: shows,
                likes: user_likes_for_shows(shows)
              }
            end

    @ambiguity_controller = 'years'
    @title = "Years: #{year1}-#{year2}"
    @view = 'shows/index'
  end

  def shows_during_year_range
    Show.published
        .between_years(year1, year2)
        .includes(:tour, :venue, show_tags: :tag)
        .order(@order_by)
  end

  def year_range_from_slug
    return false unless current_slug =~ /\A(\d{4})-(\d{4})\z/
    [Regexp.last_match[1], Regexp.last_match[2]]
  end

  def year1
    year_range_from_slug.first
  end

  def year2
    year_range_from_slug.second
  end
end
