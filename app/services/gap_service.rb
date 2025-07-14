class GapService < ApplicationService
  param :show
  option :update_previous, default: -> { false }

  def call
    update_song_gaps_for_show
    update_previous_occurrences if update_previous
  end

  private

  def update_song_gaps_for_show
    log_info "Processing show #{show.date}"

    ActiveRecord::Base.transaction do
      show.tracks.where.not(set: "S").each do |track|
        # Skip pre-show tracks that should be excluded from gap calculations
        next if should_exclude_preshow_track?(track)
        track.songs.each do |song|
          # Skip songs that should be excluded from gap calculations
          next if should_exclude_song_from_gaps?(song)

          song_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
          next unless song_track

          # Calculate normal gaps (any audio_status)
          previous_performance = find_previous_performance(song, track)
          song_track.previous_performance_gap = calculate_gap(previous_performance&.show&.date, track.show.date, previous_performance, track)
          song_track.previous_performance_slug = build_slug(previous_performance)

          next_performance = find_next_performance(song, track)
          song_track.next_performance_gap = calculate_gap(track.show.date, next_performance&.show&.date, track, next_performance)
          song_track.next_performance_slug = build_slug(next_performance)

          # Calculate gaps with audio (excluding shows with missing audio)
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
        # Skip pre-show tracks that should be excluded from gap calculations
        next if should_exclude_preshow_track?(track)

        track.songs.each do |song|
          # Skip songs that should be excluded from gap calculations
          next if should_exclude_song_from_gaps?(song)

          # Find all previous performances of this song
          previous_song_tracks = SongsTrack.joins(track: :show)
                                          .where(song:)
                                          .where("shows.date < ?", show.date)
                                          .where.not(tracks: { set: "S" })
                                          .where(shows: { exclude_from_stats: false })

          previous_song_tracks.each do |previous_song_track|
            previous_track = previous_song_track.track

            # Update next performance gaps for the previous occurrence
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
    previous_tracks = Track.joins(:show, :songs)
                           .where(songs: { id: song.id })
                           .where("tracks.set <> ?", "S")
                           .where("shows.date < ?", track.show.date)
                           .where(shows: { exclude_from_stats: false })
                           .order("shows.date DESC, tracks.position DESC")

    # Check for previous performance within the same show and same performance unit
    # Pre-show ("P") is separate from main show ("1", "2", "E")
    current_is_preshow = track.set == "P"

    if current_is_preshow
      # For pre-show tracks, look for other pre-show tracks only
      previous_tracks_within_show = track.show
                                         .tracks
                                         .joins(:songs)
                                         .where(songs: { id: song.id })
                                         .where("tracks.set <> ?", "S")
                                         .where("tracks.position < ?", track.position)
                                         .where("tracks.set = ?", "P")
                                         .order("tracks.position DESC")
    else
      # For main show tracks, look for other main show tracks (1, 2, E)
      previous_tracks_within_show = track.show
                                         .tracks
                                         .joins(:songs)
                                         .where(songs: { id: song.id })
                                         .where("tracks.set <> ?", "S")
                                         .where("tracks.position < ?", track.position)
                                         .where("tracks.set <> ?", "P") # Not pre-show
                                         .order("tracks.position DESC")
    end

    return previous_tracks_within_show.first if previous_tracks_within_show.exists?

    # Check for previous performance within same show but different performance unit
    # Only applies between pre-show and main show
    if current_is_preshow
      # For pre-show tracks, look for main show tracks
      previous_tracks_different_unit = track.show
                                            .tracks
                                            .joins(:songs)
                                            .where(songs: { id: song.id })
                                            .where("tracks.set <> ?", "S")
                                            .where("tracks.position < ?", track.position)
                                            .where("tracks.set <> ?", "P") # Main show tracks
                                            .order("tracks.position DESC")
    else
      # For main show tracks, look for pre-show tracks
      previous_tracks_different_unit = track.show
                                            .tracks
                                            .joins(:songs)
                                            .where(songs: { id: song.id })
                                            .where("tracks.set <> ?", "S")
                                            .where("tracks.position < ?", track.position)
                                            .where("tracks.set = ?", "P") # Pre-show tracks
                                            .order("tracks.position DESC")
    end

    return previous_tracks_different_unit.first if previous_tracks_different_unit.exists?

    previous_tracks.first
  end

  def find_next_performance(song, track)
    next_tracks = Track.joins(:show, :songs)
                       .where(songs: { id: song.id })
                       .where("tracks.set <> ?", "S")
                       .where("shows.date > ?", track.show.date)
                       .where(shows: { exclude_from_stats: false })
                       .order("shows.date ASC, tracks.position ASC")

    # Check for next performance within the same show and same performance unit
    # Pre-show ("P") is separate from main show ("1", "2", "E")
    current_is_preshow = track.set == "P"

    if current_is_preshow
      # For pre-show tracks, look for other pre-show tracks only
      next_tracks_within_show = track.show
                                     .tracks
                                     .joins(:songs)
                                     .where(songs: { id: song.id })
                                     .where("tracks.set <> ?", "S")
                                     .where("tracks.position > ?", track.position)
                                     .where("tracks.set = ?", "P")
                                     .order("tracks.position ASC")
    else
      # For main show tracks, look for other main show tracks (1, 2, E)
      next_tracks_within_show = track.show
                                     .tracks
                                     .joins(:songs)
                                     .where(songs: { id: song.id })
                                     .where("tracks.set <> ?", "S")
                                     .where("tracks.position > ?", track.position)
                                     .where("tracks.set <> ?", "P") # Not pre-show
                                     .order("tracks.position ASC")
    end

    return next_tracks_within_show.first if next_tracks_within_show.exists?

    # Check for next performance within same show but different performance unit
    # Only applies between pre-show and main show
    if current_is_preshow
      # For pre-show tracks, look for main show tracks
      next_tracks_different_unit = track.show
                                        .tracks
                                        .joins(:songs)
                                        .where(songs: { id: song.id })
                                        .where("tracks.set <> ?", "S")
                                        .where("tracks.position > ?", track.position)
                                        .where("tracks.set <> ?", "P") # Main show tracks
                                        .order("tracks.position ASC")
    else
      # For main show tracks, look for pre-show tracks
      next_tracks_different_unit = track.show
                                        .tracks
                                        .joins(:songs)
                                        .where(songs: { id: song.id })
                                        .where("tracks.set <> ?", "S")
                                        .where("tracks.position > ?", track.position)
                                        .where("tracks.set = ?", "P") # Pre-show tracks
                                        .order("tracks.position ASC")
    end

    return next_tracks_different_unit.first if next_tracks_different_unit.exists?

    next_tracks.first
  end

  def find_previous_performance_with_audio(song, track)
    previous_tracks = Track.joins(:show, :songs)
                           .where(songs: { id: song.id })
                           .where("tracks.set <> ?", "S")
                           .where("shows.date < ?", track.show.date)
                           .merge(Show.with_audio)
                           .where(shows: { exclude_from_stats: false })
                           .order("shows.date DESC, tracks.position DESC")

    # Only check within-show performances if current show has audio
    if track.show.audio_status != "missing"
      # Check for previous performance within the same show and same performance unit
      # Pre-show ("P") is separate from main show ("1", "2", "E")
      current_is_preshow = track.set == "P"

      if current_is_preshow
        # For pre-show tracks, look for other pre-show tracks only
        previous_tracks_within_show = track.show
                                           .tracks
                                           .joins(:songs)
                                           .where(songs: { id: song.id })
                                           .where("tracks.set <> ?", "S")
                                           .where("tracks.position < ?", track.position)
                                           .where("tracks.set = ?", "P")
                                           .order("tracks.position DESC")
      else
        # For main show tracks, look for other main show tracks (1, 2, E)
        previous_tracks_within_show = track.show
                                           .tracks
                                           .joins(:songs)
                                           .where(songs: { id: song.id })
                                           .where("tracks.set <> ?", "S")
                                           .where("tracks.position < ?", track.position)
                                           .where("tracks.set <> ?", "P") # Not pre-show
                                           .order("tracks.position DESC")
      end

      return previous_tracks_within_show.first if previous_tracks_within_show.exists?

      # Check for previous performance within same show but different performance unit
      # Only applies between pre-show and main show
      if current_is_preshow
        # For pre-show tracks, look for main show tracks
        previous_tracks_different_unit = track.show
                                              .tracks
                                              .joins(:songs)
                                              .where(songs: { id: song.id })
                                              .where("tracks.set <> ?", "S")
                                              .where("tracks.position < ?", track.position)
                                              .where("tracks.set <> ?", "P") # Main show tracks
                                              .order("tracks.position DESC")
      else
        # For main show tracks, look for pre-show tracks
        previous_tracks_different_unit = track.show
                                              .tracks
                                              .joins(:songs)
                                              .where(songs: { id: song.id })
                                              .where("tracks.set <> ?", "S")
                                              .where("tracks.position < ?", track.position)
                                              .where("tracks.set = ?", "P") # Pre-show tracks
                                              .order("tracks.position DESC")
      end

      return previous_tracks_different_unit.first if previous_tracks_different_unit.exists?
    end

    previous_tracks.first
  end

  def find_next_performance_with_audio(song, track)
    next_tracks = Track.joins(:show, :songs)
                       .where(songs: { id: song.id })
                       .where("tracks.set <> ?", "S")
                       .where("shows.date > ?", track.show.date)
                       .merge(Show.with_audio)
                       .where(shows: { exclude_from_stats: false })
                       .order("shows.date ASC, tracks.position ASC")

    # Only check within-show performances if current show has audio
    if track.show.audio_status != "missing"
      # Check for next performance within the same show and same performance unit
      # Pre-show ("P") is separate from main show ("1", "2", "E")
      current_is_preshow = track.set == "P"

      if current_is_preshow
        # For pre-show tracks, look for other pre-show tracks only
        next_tracks_within_show = track.show
                                       .tracks
                                       .joins(:songs)
                                       .where(songs: { id: song.id })
                                       .where("tracks.set <> ?", "S")
                                       .where("tracks.position > ?", track.position)
                                       .where("tracks.set = ?", "P")
                                       .order("tracks.position ASC")
      else
        # For main show tracks, look for other main show tracks (1, 2, E)
        next_tracks_within_show = track.show
                                       .tracks
                                       .joins(:songs)
                                       .where(songs: { id: song.id })
                                       .where("tracks.set <> ?", "S")
                                       .where("tracks.position > ?", track.position)
                                       .where("tracks.set <> ?", "P") # Not pre-show
                                       .order("tracks.position ASC")
      end

      return next_tracks_within_show.first if next_tracks_within_show.exists?

      # Check for next performance within same show but different performance unit
      # Only applies between pre-show and main show
      if current_is_preshow
        # For pre-show tracks, look for main show tracks
        next_tracks_different_unit = track.show
                                          .tracks
                                          .joins(:songs)
                                          .where(songs: { id: song.id })
                                          .where("tracks.set <> ?", "S")
                                          .where("tracks.position > ?", track.position)
                                          .where("tracks.set <> ?", "P") # Main show tracks
                                          .order("tracks.position ASC")
      else
        # For main show tracks, look for pre-show tracks
        next_tracks_different_unit = track.show
                                          .tracks
                                          .joins(:songs)
                                          .where(songs: { id: song.id })
                                          .where("tracks.set <> ?", "S")
                                          .where("tracks.position > ?", track.position)
                                          .where("tracks.set = ?", "P") # Pre-show tracks
                                          .order("tracks.position ASC")
      end

      return next_tracks_different_unit.first if next_tracks_different_unit.exists?
    end

    next_tracks.first
  end

    def calculate_gap(start_date, end_date, start_track = nil, end_track = nil)
    return nil if start_date.nil? || end_date.nil?

    # Check if this is a same-show different-performance-unit scenario
    if start_date == end_date && start_track && end_track
      # Only Pre-Show ("P") is treated as a separate performance unit from main show
      # Set 1, Set 2, Encore are all part of the same performance unit
      start_is_preshow = start_track.set == "P"
      end_is_preshow = end_track.set == "P"

      # Gap = 1 only if one track is pre-show and the other is main show
      return 1 if start_is_preshow != end_is_preshow
      # Same performance unit within same show
      return 0
    end

    return 0 if start_date == end_date

    # Count shows between the dates (exclusive of start and end dates)
    # PhishNet gap methodology: count shows between performances
    Show.where(date: start_date.next_day..end_date.prev_day)
        .where(exclude_from_stats: false)
        .sum do |show|
          # Special cases: certain dates count as multiple performances for PhishNet compatibility
          case show.date
          when Date.parse("1985-05-01")
            4  # 4 separate performances
          when Date.parse("1985-02-25")
            2  # 2 separate performances (Doolin's + Private Party)
          when Date.parse("2000-05-19")
            2  # 2 separate performances (Key Club shows)
          else
            # Check if this show has pre-show tracks (set = "P")
            has_preshow = show.tracks.exists?(set: "P")

            # Check if this show's pre-show should be excluded from gap calculations
            if has_preshow && excluded_preshow_dates.include?(show.date)
              1  # Pre-show exists but should be excluded from gap calculations
            else
              has_preshow ? 2 : 1
            end
          end
        end
  end

    def calculate_gap_with_audio(start_date, end_date, start_track = nil, end_track = nil)
    return nil if start_date.nil? || end_date.nil?

    # Check if this is a same-show different-performance-unit scenario
    if start_date == end_date && start_track && end_track
      # Only Pre-Show ("P") is treated as a separate performance unit from main show
      # Set 1, Set 2, Encore are all part of the same performance unit
      start_is_preshow = start_track.set == "P"
      end_is_preshow = end_track.set == "P"

      # Gap = 1 only if one track is pre-show and the other is main show
      return 1 if start_is_preshow != end_is_preshow
      # Same performance unit within same show
      return 0
    end

    return 0 if start_date == end_date

    # Count shows with audio between the dates (exclusive of start and end dates)
    # PhishNet gap methodology: count shows between performances
    Show.where(date: start_date.next_day..end_date.prev_day)
        .with_audio
        .where(exclude_from_stats: false)
        .sum do |show|
          # Special cases: certain dates count as multiple performances for PhishNet compatibility
          case show.date
          when Date.parse("1985-05-01")
            4  # 4 separate performances (but has audio_status: "missing" so won't be included)
          when Date.parse("1985-02-25")
            2  # 2 separate performances (Doolin's + Private Party)
          when Date.parse("2000-05-19")
            2  # 2 separate performances (Key Club shows)
          else
            # Check if this show has pre-show tracks (set = "P")
            has_preshow = show.tracks.exists?(set: "P")

            # Check if this show's pre-show should be excluded from gap calculations
            if has_preshow && excluded_preshow_dates.include?(show.date)
              1  # Pre-show exists but should be excluded from gap calculations
            else
              has_preshow ? 2 : 1
            end
          end
        end
  end

  def build_slug(track)
    return nil unless track
    "#{track.show.date}/#{track.slug}"
  end

  def log_info(message)
    Rails.logger.info(message) unless Rails.env.test?
  end

    def should_exclude_preshow_track?(track)
    return false unless track.set == "P"
    excluded_preshow_dates.include?(track.show.date)
  end

  def excluded_preshow_dates
    @excluded_preshow_dates ||= [
      Date.parse("1994-04-13"),  # Beacon Theatre - interviews/intro tracks not counted for stats
      Date.parse("1997-02-26"),  # Longhorn - interviews/talk tracks not counted for stats
      Date.parse("2014-06-24"),  # Ed Sullivan Theater - "The Line" pre-show not counted for stats
      Date.parse("2023-08-25"),  # Saratoga Performing Arts Center - acoustic pre-show not counted for stats
      Date.parse("2023-08-26")   # Saratoga Performing Arts Center - acoustic pre-show not counted for stats
    ]
  end

  def should_exclude_song_from_gaps?(song)
    # Exclude songs that are inconsistent between systems or not meaningful for gap calculations
    excluded_song_titles = [ "Intro", "Outro", "Jam" ]
    excluded_song_titles.include?(song.title)
  end
end
