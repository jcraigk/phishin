module Ambiguity::VenueName
  def slug_as_venue
    return false if venue.blank?

    validate_sorting_for_shows
    hydrate_venue_page

    true
  end

  private

  def venue
    @venue ||= Venue.includes(:venue_renames).find_by(slug: current_slug)
  end

  def hydrate_venue_page
    @ogp_title = "Listen to shows from #{venue.name}"
    @shows = venue.shows.includes(show_tags: :tag).order(@order_by)
    @shows_likes = user_likes_for_shows(@shows)
    @previous_venue = prev_venue
    @next_venue = next_venue

    @view = 'venues/show'
    @ambiguity_controller = 'venues'
  end

  def prev_venue
    Venue.where('name < ?', venue.name).order(name: :desc).first ||
      Venue.order(name: :desc).first
  end

  def next_venue
    Venue.where('name > ?', venue.name).order(name: :asc).first ||
      Venue.order(name: :asc).first
  end
end
