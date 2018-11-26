# frozen_string_literal: true
module Ambiguity::VenueName
  def slug_as_venue
    slug = params[:slug]
    return false unless (@venue = Venue.find_by(slug: slug.downcase))

    @shows = @venue.shows.includes(:tags).order(@order_by)
    @shows_likes = user_likes_for_shows(@shows)
    @next_venue = Venue.relevant.where('name > ?', @venue.name).order(name: :asc).first
    @next_venue = Venue.relevant.order(name: :asc).first if @next_venue.nil?
    @previous_venue = Venue.relevant.where('name < ?', @venue.name).order(name: :desc).first
    @previous_venue = Venue.relevant.order(name: :desc).first if @previous_venue.nil?

    @view = 'venues/show'
    @ambiguous_controller = 'venues'

    true
  end
end
