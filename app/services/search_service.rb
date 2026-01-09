class SearchService < ApplicationService
  option :term
  option :scope, default: proc { "all" }
  option :audio_status, default: proc { "any" }

  LIMIT = 50
  SCOPES = %w[all playlists shows songs tags tours tracks venues]

  def call
    return if term_too_short?
    results = search_results
    merge_tag_matches(results)
    results
  end

  private

  def term_too_short?
    term.size.to_i < App.min_search_term_length
  end

  def merge_tag_matches(results)
    # Add Show Tag matches to other_shows
    if results[:show_tags].present?
      ids = results[:show_tags].map(&:show_id) + (results[:other_shows]&.map(&:id) || [])
      results[:other_shows] = Show.includes(:venue, :tour, show_tags: :tag).where(id: ids)
    end

    # Add Track Tag matches to tracks
    if results[:track_tags].present?
      ids = results[:track_tags].map(&:track_id) + (results[:tracks]&.map(&:id) || [])
      results[:tracks] = Track.includes(:show).where(id: ids)
    end
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
    when "tours"
      { tours: }
    else
      {
        songs:,
        venues:,
        tags:,
        show_tags:,
        track_tags:,
        tracks: tracks_filtered_by_songs,
        playlists:,
        tours:
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
    scope = Show.all
    scope = apply_audio_status_filter(scope)
    scope.includes(:venue, :tour, show_tags: :tag).find_by(date:)
  end

  def shows_on_day_of_year
    return [] unless term_is_date?
    scope = Show.all
    scope = apply_audio_status_filter(scope)
    scope.on_day_of_year(date[5..6], date[8..9])
         .where.not(date:)
         .includes(:venue, :tour, show_tags: :tag)
         .order(date: :desc)
  end

  def songs
    return [] if term_is_date?
    scope = Song.where("songs.title ILIKE :term OR songs.alias ILIKE :term", term: "%#{term}%")
               .limit(LIMIT)

    # Filter songs to only include those with audio if audio_status is complete_or_partial
    if audio_status == "complete_or_partial"
      scope = scope.joins(songs_tracks: { track: :show })
                   .merge(Show.with_audio)
                   .distinct
                   .order("songs.title ASC")
    else
      scope = scope.order(title: :asc)
    end

    scope
  end

  def venues
    return [] if term_is_date?
    scope = Venue.left_outer_joins(:venue_renames)
                 .where(venue_where_str, term: "%#{term}%")
                 .order(name: :asc)
                 .distinct

    # Filter venues to only include those with shows with audio if audio_status is complete_or_partial
    if audio_status == "complete_or_partial"
      scope = scope.where("venues.shows_with_audio_count > 0")
    end

    scope
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
    scope = scope.joins(:show).then { |s| apply_audio_status_filter(s, :show) }
    scope.where("notes ILIKE ?", "%#{term}%")
         .order("tags.name, shows.date")
         .limit(LIMIT)
  end

  def track_tags
    scope = TrackTag.includes(:tag, track: :show)
    scope = scope.joins(track: :show).then { |s| apply_audio_status_filter(s, :show) }
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
    scope = scope.joins(:show).then { |s| apply_audio_status_filter(s, :show) }
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

  def tours
    Tour.where("name ILIKE :term OR slug ILIKE :term", term: "%#{term}%")
        .order(starts_on: :desc)
        .limit(LIMIT)
  end

  def apply_audio_status_filter(relation, table_prefix = nil)
    case audio_status
    when "complete", "partial", "missing"
      if table_prefix == :show
        relation.where(shows: { audio_status: })
      else
        relation.where(audio_status:)
      end
    when "complete_or_partial"
      if table_prefix == :show
        relation.where(shows: { audio_status: %w[complete partial] })
      else
        relation.with_audio
      end
    else
      relation
    end
  end
end
