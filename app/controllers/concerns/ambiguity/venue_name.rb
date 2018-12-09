# frozen_string_literal: true
module Ambiguity::VenueName
  def slug_as_venue
    return false unless venue.present?

    hydrate_venue_page

    true
  end

  private

  def venue
    @venue ||= Venue.find_by(slug: current_slug)
  end

  def hydrate_venue_page
    @shows = venue.shows.includes(:show_tags).order(@order_by)
    @shows_likes = user_likes_for_shows(@shows)
    @previous_venue = prev_venue
    @next_venue = next_venue

    @view = 'venues/show'
    @ambiguity_controller = 'venues'
  end

  def prev_venue
    Venue.relevant
         .where('name < ?', venue.name)
         .order(name: :desc)
         .first ||
      Venue.relevant
           .order(name: :desc)
           .first
  end

  def next_venue
    Venue.relevant
         .where('name > ?', venue.name)
         .order(name: :asc)
         .first ||
      Venue.relevant
           .order(name: :asc)
           .first
  end
end
