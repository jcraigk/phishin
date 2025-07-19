# This service is used to calculate the gaps between performances
# of the same song across different shows.

# If update_previous is true, it will also update the `next` gaps for
# previous occurrences of songs that were played at specified show.

class GapService < ApplicationService
  param :show
  option :update_previous, default: -> { false }

  EXCLUDED_SONG_TITLES = %w[Intro Outro Banter Interview Jam]

  def call
    update_song_gaps_for_show
    update_previous_occurrences if update_previous
  end

  private

  def update_song_gaps_for_show
    log_info "Processing show #{show.date}"

    ActiveRecord::Base.transaction do
      show.tracks.where.not(set: "S").each do |track|
        next if should_exclude_track?(track)

        track.songs.each do |song|
          next if should_exclude_song_from_gaps?(song)

          song_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
          next unless song_track

          previous_performance = find_previous_performance(song, track)
          song_track.previous_performance_gap = calculate_gap(previous_performance&.show&.date, track.show.date, previous_performance, track)
          song_track.previous_performance_slug = build_slug(previous_performance)

          next_performance = find_next_performance(song, track)
          song_track.next_performance_gap = calculate_gap(track.show.date, next_performance&.show&.date, track, next_performance)
          song_track.next_performance_slug = build_slug(next_performance)

          previous_performance_with_audio = find_previous_performance_with_audio(song, track)
          song_track.previous_performance_gap_with_audio = calculate_gap_with_audio(previous_performance_with_audio&.show&.date, track.show.date, previous_performance_with_audio, track)
          song_track.previous_performance_slug_with_audio = build_slug(previous_performance_with_audio)

          next_performance_with_audio = find_next_performance_with_audio(song, track)
          song_track.next_performance_gap_with_audio = calculate_gap_with_audio(track.show.date, next_performance_with_audio&.show&.date, track, next_performance_with_audio)
          song_track.next_performance_slug_with_audio = build_slug(next_performance_with_audio)

          song_track.save!

          log_info "💾 Updated gaps for '#{song.title}' (track #{track.position}): " \
                   "prev=#{song_track.previous_performance_gap}, " \
                   "next=#{song_track.next_performance_gap}, " \
                   "prev_audio=#{song_track.previous_performance_gap_with_audio}, " \
                   "next_audio=#{song_track.next_performance_gap_with_audio}"
        end
      end
    end

    log_info "✅ Completed processing show #{show.date}"
  end

  def update_previous_occurrences
    log_info "🔄 Updating previous occurrences for show #{show.date}"

    ActiveRecord::Base.transaction do
      show.tracks.where.not(set: "S").each do |track|
        next if should_exclude_track?(track)

        track.songs.each do |song|
          next if should_exclude_song_from_gaps?(song)

          previous_song_tracks = SongsTrack.joins(track: :show)
                                          .where(song:)
                                          .where("shows.date < ?", show.date)
                                          .joins("JOIN tracks ON tracks.id = songs_tracks.track_id")
                                          .where.not(tracks: { set: "S" })
                                          .where.not(tracks: { exclude_from_performance_gaps: true })
                                          .where("shows.performance_gap_value > 0")

          previous_song_tracks.each do |previous_song_track|
            previous_track = previous_song_track.track

            next if should_exclude_track?(previous_track)

            next_performance = find_next_performance(song, previous_track)
            previous_song_track.next_performance_gap = calculate_gap(previous_track.show.date, next_performance&.show&.date, previous_track, next_performance)
            previous_song_track.next_performance_slug = build_slug(next_performance)

            next_performance_with_audio = find_next_performance_with_audio(song, previous_track)
            previous_song_track.next_performance_gap_with_audio = calculate_gap_with_audio(previous_track.show.date, next_performance_with_audio&.show&.date, previous_track, next_performance_with_audio)
            previous_song_track.next_performance_slug_with_audio = build_slug(next_performance_with_audio)

            previous_song_track.save!

            log_info "🔄 Updated next gaps for '#{song.title}' from #{previous_track.show.date}: " \
                     "next=#{previous_song_track.next_performance_gap}, " \
                     "next_audio=#{previous_song_track.next_performance_gap_with_audio}"
          end
        end
      end
    end

    log_info "✅ Completed updating previous occurrences for show #{show.date}"
  end

  def find_previous_performance(song, track)
    find_performance(song, track, direction: :previous, audio_required: false)
  end

  def find_next_performance(song, track)
    find_performance(song, track, direction: :next, audio_required: false)
  end

  def find_previous_performance_with_audio(song, track)
    find_performance(song, track, direction: :previous, audio_required: true)
  end

  def find_next_performance_with_audio(song, track)
    find_performance(song, track, direction: :next, audio_required: true)
  end

  private

  def find_performance(song, track, direction:, audio_required: false)
    base_query = Track.joins(:show, :songs)
                      .where(songs: { id: song.id })
                      .where("tracks.set <> ?", "S")
                      .where.not(tracks: { exclude_from_performance_gaps: true })
                      .where("shows.performance_gap_value > 0")

    base_query = base_query.merge(Show.with_audio) if audio_required

    if direction == :previous
      cross_show_tracks = base_query
                            .where("shows.date < ?", track.show.date)
                            .order("shows.date DESC, tracks.position DESC")
    else
      cross_show_tracks = base_query
                            .where("shows.date > ?", track.show.date)
                            .order("shows.date ASC, tracks.position ASC")
    end

    if !audio_required || track.show.audio_status != "missing"
      within_show_track = find_tracks_within_show(song, track, direction)
      return within_show_track if within_show_track

      different_unit_track = find_tracks_different_unit(song, track, direction)
      return different_unit_track if different_unit_track
    end

    cross_show_tracks.first
  end

  def find_tracks_within_show(song, track, direction)
    current_is_preshow = track.set == "P"
    position_operator = direction == :previous ? "<" : ">"
    position_order = direction == :previous ? "DESC" : "ASC"

    base_query = track.show
                      .tracks
                      .joins(:songs)
                      .where(songs: { id: song.id })
                      .where("tracks.set <> ?", "S")
                      .where.not(tracks: { exclude_from_performance_gaps: true })
                      .where("tracks.position #{position_operator} ?", track.position)

    if current_is_preshow
      tracks_within_show = base_query
                            .where("tracks.set = ?", "P")
                            .order("tracks.position #{position_order}")
    else
      tracks_within_show = base_query
                            .where("tracks.set <> ?", "P") # Not pre-show
                            .order("tracks.position #{position_order}")
    end

    tracks_within_show.first
  end

  def find_tracks_different_unit(song, track, direction)
    current_is_preshow = track.set == "P"
    position_operator = direction == :previous ? "<" : ">"
    position_order = direction == :previous ? "DESC" : "ASC"

    base_query = track.show
                      .tracks
                      .joins(:songs)
                      .where(songs: { id: song.id })
                      .where("tracks.set <> ?", "S")
                      .where.not(tracks: { exclude_from_performance_gaps: true })
                      .where("tracks.position #{position_operator} ?", track.position)

    if current_is_preshow
      tracks_different_unit = base_query
                               .where("tracks.set <> ?", "P") # Main show tracks
                               .order("tracks.position #{position_order}")
    else
      tracks_different_unit = base_query
                               .where("tracks.set = ?", "P") # Pre-show tracks
                               .order("tracks.position #{position_order}")
    end

    tracks_different_unit.first
  end

  def calculate_gap(start_date, end_date, start_track = nil, end_track = nil, audio_required: false)
    return nil if start_date.nil? || end_date.nil?

    if start_date == end_date && start_track && end_track
      return 1 if different_performance_units?(start_track, end_track)
      return 0
    end

    return 0 if start_date == end_date

    # Count shows between the dates (exclusive of start and end dates)
    # Use performance_gap_value to determine how much each show counts
    # Add 1 to match PhishNet methodology (consecutive shows = gap of 1)
    shows_query = Show.where(date: start_date.next_day..end_date.prev_day)
                      .where("performance_gap_value > 0")

    shows_query = shows_query.with_audio if audio_required

    shows_query.sum(:performance_gap_value) + 1
  end

  def calculate_gap_with_audio(start_date, end_date, start_track = nil, end_track = nil)
    calculate_gap(start_date, end_date, start_track, end_track, audio_required: true)
  end

  def different_performance_units?(track1, track2)
    # Only Pre-Show ("P") is treated as a separate performance unit from main show
    # Set 1, Set 2, Encore are all part of the same performance unit
    (track1.set == "P") != (track2.set == "P")
  end

  def count_performances_for_show(show)
    show.performance_gap_value
  end

  def build_slug(track)
    return nil unless track
    "#{track.show.date}/#{track.slug}"
  end

  def log_info(message)
    Rails.logger.info(message) unless Rails.env.test?
  end

  def should_exclude_track?(track)
    track.exclude_from_performance_gaps? || single_song_with_excluded_title?(track)
  end

  def single_song_with_excluded_title?(track)
    return false unless track.songs.count == 1

    song_title = track.songs.first.title
    EXCLUDED_SONG_TITLES.include?(song_title)
  end

  def should_exclude_song_from_gaps?(song)
    EXCLUDED_SONG_TITLES.include?(song.title)
  end
end
