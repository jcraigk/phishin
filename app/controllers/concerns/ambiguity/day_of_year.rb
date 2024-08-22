module Ambiguity::DayOfYear
  TODAY_SLUGS = %w[today today-in-history].freeze

  def slug_as_day_of_year
    return false if month_day_from_slug.blank?

    validate_sorting_for_shows
    fetch_shows_on_day_of_year
    apply_shows_tag_filter
    hydrate_day_of_year

    true
  end

  private

  def hydrate_day_of_year
    @sections = day_of_year_sections
    @pretitle = "Today in History" if current_slug.in?(TODAY_SLUGS)
    @title = "#{Date::MONTHNAMES[month]} #{day}"
    @ogp_title = "Listen to shows on #{@title}"
    @view = "shows/index"
  end

  def fetch_shows_on_day_of_year
    @shows =
      Show.published
          .on_day_of_year(month, day)
          .includes(:tour, :venue, show_tags: :tag)
          .order(@order_by)
    raise ActiveRecord::RecordNotFound unless @shows.any?
  end

  def day_of_year_sections
    {
      "Today in History" => {
        shows: @shows,
        likes: user_likes_for_shows(@shows)
      }
    }
  end

  def month
    @month ||= month_day_from_slug.first
  end

  def day
    @day ||= month_day_from_slug.second
  end

  def month_day_from_slug
    return [ current_month, current_day ] if current_slug.in?(TODAY_SLUGS)
    return false unless current_slug =~ month_day_regex
    [ Date::MONTHNAMES.index(Regexp.last_match[1].titleize), Regexp.last_match[2] ]
  end

  def month_day_regex
    /
      \A
      (january|february|march|april|may|june|july|august|september|october|november|december)
      -
      (\d{1,2})
      \z
    /xi
  end

  def current_month
    Time.use_zone(App.time_zone) { Time.current }.strftime("%-m").to_i
  end

  def current_day
    Time.use_zone(App.time_zone) { Time.current }.strftime("%-d").to_i
  end
end
