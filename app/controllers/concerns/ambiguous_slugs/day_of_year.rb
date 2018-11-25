# frozen_string_literal: true
module AmbiguousSlugs::DayOfYear
  def slug_as_day_of_year
    slug = params[:slug]
    return false unless slug.match(
      /\A(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})\z/i
    )

    validate_sorting_for_shows

    r = Regexp.last_match
    month_name = r[1].titleize
    month_num = Date::MONTHNAMES.index(month_name)
    day_num = Integer(r[2], 10)

    @shows =
      Show.avail
          .on_day_of_year(month_num, day_num)
          .includes(:tour, :venue, :tags)
          .order(@order_by)
    @sections = {}
    @shows.group_by(&:tour_name).each do |tour, show_list|
      @sections[tour] = {
        shows: show_list,
        likes: user_likes_for_shows(show_list)
      }
    end

    @title = "#{month_name} #{day_num}"
    @view = 'shows/index'

    raise ActiveRecord::RecordNotFound unless @shows.any?
    true
  end
end
