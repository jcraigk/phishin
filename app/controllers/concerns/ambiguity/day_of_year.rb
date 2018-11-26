# frozen_string_literal: true
module Ambiguity::DayOfYear
  def slug_as_day_of_year
    return false unless month_day_from_slug.present?

    validate_sorting_for_shows
    fetch_shows_on_day_of_year
    hydrate_day_of_year

    true
  end

  private

  def hydrate_day_of_year
    @sections = day_of_year_sections
    @title = "#{Date::MONTHNAMES[month]} #{day}"
    @view = 'shows/index'
  end

  def fetch_shows_on_day_of_year
    @shows =
      Show.avail
          .on_day_of_year(month, day)
          .includes(:tour, :venue, :tags)
          .order(@order_by)
    raise ActiveRecord::RecordNotFound unless @shows.all.any?
  end

  def day_of_year_sections
    @shows.group_by(&:tour_name)
          .each_with_object({}) do |(tour, shows), sections|
            sections[tour] = {
              shows: shows,
              likes: user_likes_for_shows(shows)
            }
          end
  end

  def month
    @month ||= month_day_from_slug.first
  end

  def day
    @day ||= month_day_from_slug.second
  end

  def month_day_from_slug
    return false unless current_slug =~ month_day_regex
    [Date::MONTHNAMES.index(Regexp.last_match[1].titleize), Regexp.last_match[2]]
  end

  def month_day_regex
    /\A(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})\z/i
  end
end
