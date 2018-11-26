# frozen_string_literal: true
module Ambiguity::TourName
  def slug_as_tour
    return false unless tour.present?

    hydrate_tour_page

    true
  end

  private

  def tour
    @tour ||= Tour.includes(shows: :tags).find_by(slug: current_slug)
  end

  def hydrate_tour_page
    @shows = @tour.shows.sort_by(&:date).reverse
    @shows_likes = user_likes_for_shows(@shows)
    @sections = {
      @tour.name => {
        shows: @shows,
        likes: @shows_likes
      }
    }

    @title = @tour.name
    @view = 'shows/index'
  end
end
