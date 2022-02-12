# frozen_string_literal: true
class SearchService
  attr_reader :term

  def initialize(term)
    @term = term || ''
  end

  def call
    return if term_too_short?
    search_results
  end

  private

  def term_too_short?
    term.size.to_i < MIN_SEARCH_TERM_LENGTH
  end

  def search_results
    date_results.merge(text_results)
  end

  def date_results
    {
      exact_show: show_on_date,
      other_shows: shows_on_day_of_year
    }
  end

  def text_results
    {
      songs:,
      venues:,
      tours:,
      tags:,
      show_tags:,
      track_tags:
    }
  end

  def date
    @date ||= DateParser.new(term).call
  end

  def term_is_date?
    date.present?
  end

  def show_on_date
    return unless term_is_date?
    Show.published.includes(:venue).find_by(date:)
  end

  def shows_on_day_of_year
    return [] unless term_is_date?
    Show.published
        .on_day_of_year(date[5..6], date[8..9])
        .where.not(date:)
        .includes(:venue)
        .order(date: :desc)
  end

  def songs
    return [] if term_is_date?
    Song.where(
      'title ILIKE :term OR alias ILIKE :term OR lyrics ILIKE :term',
      term: "%#{term}%"
    ).order(title: :asc)
  end

  def venues
    return [] if term_is_date?
    Venue.left_outer_joins(:venue_renames)
         .where(venue_where_str, term: "%#{term}%")
         .order(name: :asc)
         .uniq
  end

  def tours
    return [] if term_is_date?
    Tour.where('name ILIKE ?', "%#{term}%").order(name: :asc)
  end

  def venue_where_str
    'venues.name ILIKE :term OR venues.abbrev ILIKE :term ' \
      'OR venue_renames.name ILIKE :term ' \
      'OR venues.city ILIKE :term OR venues.state ILIKE :term ' \
      'OR venues.country ILIKE :term '
  end

  def tags
    Tag.where('name ILIKE :term OR description ILIKE :term', term: "%#{term}%")
       .order(name: :asc)
  end

  def show_tags
    ShowTag.includes(:tag, :show)
           .where('notes ILIKE ?', "%#{term}%")
           .order('tags.name, shows.date')
           .limit(200)
  end

  def track_tags
    TrackTag.includes(:tag, track: :show)
            .where('notes ILIKE ?', "%#{term}%")
            .order('tags.name, shows.date, tracks.position')
            .limit(200)
  end
end
