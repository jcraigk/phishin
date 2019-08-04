# frozen_string_literal: true
module Ambiguity::Year
  def slug_as_year
    return false if year_from_slug.blank?

    validate_sorting_for_shows
    hydrate_year_page

    raise ActiveRecord::RecordNotFound unless @shows.any?

    true
  end

  private

  def year_from_slug
    current_slug =~ /\A\d{4}\z/
  end

  def shows_during_year
    Show.during_year(current_slug)
        .includes(:tour, :venue, show_tags: :tag)
        .order(@order_by)
  end

  def hydrate_year_page
    @shows = shows_during_year
    @sections =
      @shows.group_by(&:tour_name)
            .each_with_object({}) do |(tour, shows), sections|
              sections[tour] = {
                shows: shows,
                likes: user_likes_for_shows(shows)
              }
            end

    @ambiguity_controller = 'years'
    @title = "Year: #{current_slug}"
    @view = 'shows/index'
  end
end
