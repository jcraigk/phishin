# frozen_string_literal: true
class SearchService
  attr_reader :term

  def initialize(term)
    @term = term
  end

  def call
    {
      show: show_on_date,
      other_shows: shows_on_day_of_year,
      songs: songs,
      venues: venues,
      tours: tours
    }
  end

  private

  def date
    @date ||= DateParserService.new(term).call
  end

  def term_is_date?
    date.present?
  end

  def show_on_date
    return unless term_is_date?
    Show.published
        .includes(:venue)
        .find_by(date: date)
  end

  def shows_on_day_of_year
    return [] unless term_is_date?
    Show.published
        .on_day_of_year(date[5..6], date[8..9])
        .where('date != ?', date)
        .includes(:venue)
        .order(date: :desc)
  end

  def songs
    return [] if term_is_date?
    Song.relevant
        .where('title ILIKE ?', "%#{term}%")
        .order(title: :asc)
  end

  def venues
    return [] if term_is_date?
    Venue.left_outer_joins(:venue_renames)
         .relevant
         .where(venue_where_str, term: "%#{term}%")
         .order(name: :asc)
         .uniq
  end

  def tours
    return [] if term_is_date?
    Tour.where('name ILIKE ?', "%#{term}%")
        .order(name: :asc)
  end

  def venue_where_str
    'venues.name ILIKE :term OR venues.abbrev ILIKE :term ' \
    'OR venue_renames.name ILIKE :term ' \
    'OR venues.city ILIKE :term OR venues.state ILIKE :term ' \
    'OR venues.country ILIKE :term '
  end
end
