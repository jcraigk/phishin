class SearchService < BaseService
  extend Dry::Initializer

  param :term
  param :scope, default: proc { "all" }

  LIMIT = 50

  def initialize(term, scope = nil)
    super(term, scope || "all") # Ensure scope defaults to "all" if nil
  end

  def call
    return if term_too_short?
    search_results
  end

  private

  def term_too_short?
    term.size.to_i < App.min_search_term_length
  end

  def search_results
    results = {}
    results.merge!(date_results)
    results.merge!(text_results)
    results
  end

  def date_results
    return {} unless scope == "all" || scope == "shows"
    {
      exact_show: show_on_date,
      other_shows: shows_on_day_of_year
    }
  end

  def text_results
    case scope
    when "shows"
      {}
    when "songs"
      { songs: }
    when "venues"
      { venues: }
    when "tours"
      { tours: }
    when "tags"
      { tags:, show_tags:, track_tags: }
    else
      {
        songs:,
        venues:,
        tours:,
        tags:,
        show_tags:,
        track_tags:,
        tracks: tracks_filtered_by_songs
      }
    end
  end

  def date
    @date ||= Chronic.parse(term).to_s
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
    Song.where("title ILIKE :term OR alias ILIKE :term", term: "%#{term}%")
        .order(title: :asc)
        .limit(LIMIT)
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
    Tour.where("name ILIKE ?", "%#{term}%").order(name: :asc).limit(LIMIT)
  end

  def venue_where_str
    "venues.name ILIKE :term OR venues.abbrev ILIKE :term " \
      "OR venue_renames.name ILIKE :term " \
      "OR venues.city ILIKE :term OR venues.state ILIKE :term " \
      "OR venues.country ILIKE :term"
  end

  def tags
    Tag.where("name ILIKE :term OR description ILIKE :term", term: "%#{term}%")
       .order(name: :asc)
       .limit(LIMIT)
  end

  def show_tags
    ShowTag.includes(:tag, :show)
           .where("notes ILIKE ?", "%#{term}%")
           .order("tags.name, shows.date")
           .limit(LIMIT)
  end

  def track_tags
    TrackTag.includes(:tag, track: :show)
            .where("notes ILIKE ?", "%#{term}%")
            .order("tags.name, shows.date, tracks.position")
            .limit(LIMIT)
  end

  def song_titles
    @song_titles ||= songs.map(&:title)
  end

  # Return only tracks that don't have a song title that matches the search term
  # since those would produce essentially duplicate search results
  def tracks_filtered_by_songs
    tracks_by_title.reject { |track| track.title.in?(song_titles) }
  end

  def tracks_by_title
    Track.where("title ILIKE ?", "%#{term}%")
         .order(title: :asc)
         .limit(LIMIT)
  end
end
