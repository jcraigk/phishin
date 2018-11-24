# frozen_string_literal: true
module AmbiguousSlugs::TourName
  def slug_as_tour
    slug = params[:slug]
    return false unless (@tour = Tour.includes(shows: :tags).find_by(slug: slug))

    @shows = @tour.shows.sort_by(&:date).reverse
    # @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @shows_likes = []
    @sections = { @tour.name => { shows: @shows, likes: [] } }

    @title = @tour.name
    @view = 'shows/index'

    true
  end
end
