# frozen_string_literal: true
module AmbiguousSlugs::TourName
  def slug_as_tour
    slug = params[:slug]
    return false unless (@tour = Tour.includes(shows: :tags).find_by(slug: slug))

    @shows = @tour.shows.sort_by(&:date).reverse
    @shows_likes = get_user_likes_for_shows(@shows)
    @sections = { @tour.name => { shows: @shows, likes: @shows_likes } }

    @title = @tour.name
    @view = 'shows/index'

    true
  end
end
