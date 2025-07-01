class SearchService < ApplicationService
  option :term
  option :scope, default: proc { "all" }
  option :api_version, default: proc { "v2" }

  LIMIT = 50
  SCOPES = %w[all playlists shows songs tags tracks venues]

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
    when "tags"
      { tags:, show_tags:, track_tags: }
    when "tracks"
      { tracks: tracks_filtered_by_songs }
    when "playlists"
      { playlists: }
    else
      {
        songs:,
        venues:,
        tags:,
        show_tags:,
        track_tags:,
        tracks: tracks_filtered_by_songs,
        playlists:
      }
    end
  end

  def date
    @date ||= Chronic.parse(term).to_s
  rescue StandardError
    nil
  end

  def term_is_date?
    date.present?
  end

  def show_on_date
    return unless term_is_date?
    scope = Show.published
    scope = scope.where.not(audio_status: "missing") if api_version == "v1"
    scope.includes(:venue).find_by(date:)
  end

  def shows_on_day_of_year
    return [] unless term_is_date?
    scope = Show.published
    scope = scope.where.not(audio_status: "missing") if api_version == "v1"
    scope.on_day_of_year(date[5..6], date[8..9])
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
    scope = ShowTag.includes(:tag, :show)
    scope = scope.joins(:show).where.not(shows: { audio_status: "missing" }) if api_version == "v1"
    scope.where("notes ILIKE ?", "%#{term}%")
         .order("tags.name, shows.date")
         .limit(LIMIT)
  end

  def track_tags
    scope = TrackTag.includes(:tag, track: :show)
    scope = scope.joins(track: :show).where.not(shows: { audio_status: "missing" }) if api_version == "v1"
    scope.where("notes ILIKE ?", "%#{term}%")
         .order("tags.name, shows.date, tracks.position")
         .limit(LIMIT)
  end

  def song_titles
    @song_titles ||= songs.map(&:title)
  end

  def tracks_filtered_by_songs
    tracks_by_title.reject { |track| track.title.in?(song_titles) }
  end

  def tracks_by_title
    scope = Track.includes(:show)
    scope = scope.joins(:show).where.not(shows: { audio_status: "missing" }) if api_version == "v1"
    scope.where("title ILIKE ?", "%#{term}%")
         .order(title: :asc)
         .limit(LIMIT)
  end

  def playlists
    Playlist.published
            .includes(:user)
            .where("name ILIKE :term OR description ILIKE :term", term: "%#{term}%")
            .order(name: :asc)
            .limit(LIMIT)
  end
end
