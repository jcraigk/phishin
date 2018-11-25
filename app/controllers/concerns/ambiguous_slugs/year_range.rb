# frozen_string_literal: true
module AmbiguousSlugs::YearRange
  def slug_as_year_range
    slug = params[:slug]
    return false unless slug =~ /\A(\d{4})-(\d{4})\z/

    validate_sorting_for_shows

    r = Regexp.last_match
    @shows = Show.avail
                 .between_years(r[1], r[2])
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
    @sections = {}
    @shows.group_by(&:tour_name).each do |tour, show_list|
      @sections[tour] = {
        shows: show_list,
        # likes: show_list.map { |s| get_user_show_like(s) }
        likes: []
      }
    end

    @ambiguous_controller = 'years'
    @title = "Years: #{r[1]}-#{r[2]}"
    @view = 'shows/index'

    raise ActiveRecord::RecordNotFound unless @shows.any?
    true
  end
end
