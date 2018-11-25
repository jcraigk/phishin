# frozen_string_literal: true
module AmbiguousSlugs::Year
  def slug_as_year
    slug = params[:slug]
    return false unless /\A\d{4}\z/.match?(slug)

    validate_sorting_for_shows
    @shows = Show.avail
                 .during_year(slug)
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
    @title = "Year: #{slug}"
    @view = 'shows/index'

    raise ActiveRecord::RecordNotFound unless @shows.any?
    true
  end
end
