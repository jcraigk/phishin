# frozen_string_literal: true

class SearchService
  attr_reader :term

  def initialize(term)
    @term = term
  end

  def results
    if (date = DateParserService.new(term).parse)
      show =
        Show.avail
            .where(date: date)
            .includes(:venue)
            .first
      other_shows =
        Show.avail
            .on_day_of_year(date[5..6], date[8..9])
            .where('date != ?', date)
            .includes(:venue)
            .order(date: :desc)
    else
      songs =
        Song.relevant
            .where('title ILIKE ?', "%#{term}%")
            .order('title asc')
      venues =
        Venue.relevant
             .where(venue_where_str, term: "%#{term}%")
             .order('name asc')
      tours =
        Tour.where('name ILIKE ?', "%#{term}%")
            .order('name asc')
    end
    {
      show: show,
      other_shows: other_shows,
      songs: songs,
      venues: venues,
      tours: tours
    }
  end

  private

  def venue_where_str
    'name ILIKE :term OR abbrev ILIKE :term ' \
    'OR past_names ILIKE :term OR city ILIKE :term ' \
    'OR state ILIKE :term OR country ILIKE :term'
  end
end
