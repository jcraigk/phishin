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
        track.songs.each do |song|
          song_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
          next unless song_track

          # Calculate normal gaps (any audio_status)
          previous_performance = find_previous_performance(song, track)
          song_track.previous_performance_gap = calculate_gap(previous_performance&.show&.date, track.show.date)
          song_track.previous_performance_slug = build_slug(previous_performance)

          next_performance = find_next_performance(song, track)
          song_track.next_performance_gap = calculate_gap(track.show.date, next_performance&.show&.date)
          song_track.next_performance_slug = build_slug(next_performance)

          # Calculate gaps with audio (excluding shows with missing audio)
          previous_performance_with_audio = find_previous_performance_with_audio(song, track)
          song_track.previous_performance_gap_with_audio = calculate_gap_with_audio(previous_performance_with_audio&.show&.date, track.show.date)
          song_track.previous_performance_slug_with_audio = build_slug(previous_performance_with_audio)

          next_performance_with_audio = find_next_performance_with_audio(song, track)
          song_track.next_performance_gap_with_audio = calculate_gap_with_audio(track.show.date, next_performance_with_audio&.show&.date)
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
        track.songs.each do |song|
          # Find all previous performances of this song
          previous_song_tracks = SongsTrack.joins(track: :show)
                                          .where(song: song)
                                          .where("shows.date < ?", show.date)
                                          .where.not(tracks: { set: "S" })
                                          .where(shows: { exclude_from_stats: false })

          previous_song_tracks.each do |previous_song_track|
            previous_track = previous_song_track.track

            # Update next performance gaps for the previous occurrence
            next_performance = find_next_performance(song, previous_track)
            previous_song_track.next_performance_gap = calculate_gap(previous_track.show.date, next_performance&.show&.date)
            previous_song_track.next_performance_slug = build_slug(next_performance)

            next_performance_with_audio = find_next_performance_with_audio(song, previous_track)
            previous_song_track.next_performance_gap_with_audio = calculate_gap_with_audio(previous_track.show.date, next_performance_with_audio&.show&.date)
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

    previous_tracks_within_show = track.show
                                       .tracks
                                       .joins(:songs)
                                       .where(songs: { id: song.id })
                                       .where("tracks.set <> ?", "S")
                                       .where("tracks.position < ?", track.position)
                                       .order("tracks.position DESC")

    return previous_tracks_within_show.first if previous_tracks_within_show.exists?

    previous_tracks.first
  end

  def find_next_performance(song, track)
    next_tracks = Track.joins(:show, :songs)
                       .where(songs: { id: song.id })
                       .where("tracks.set <> ?", "S")
                       .where("shows.date > ?", track.show.date)
                       .where(shows: { exclude_from_stats: false })
                       .order("shows.date ASC, tracks.position ASC")

    next_tracks_within_show = track.show
                                   .tracks
                                   .joins(:songs)
                                   .where(songs: { id: song.id })
                                   .where("tracks.set <> ?", "S")
                                   .where("tracks.position > ?", track.position)
                                   .order("tracks.position ASC")

    return next_tracks_within_show.first if next_tracks_within_show.exists?

    next_tracks.first
  end

  def find_previous_performance_with_audio(song, track)
    previous_tracks = Track.joins(:show, :songs)
                           .where(songs: { id: song.id })
                           .where("tracks.set <> ?", "S")
                           .where("shows.date < ?", track.show.date)
                           .where.not(shows: { audio_status: "missing" })
                           .where(shows: { exclude_from_stats: false })
                           .order("shows.date DESC, tracks.position DESC")

    previous_tracks_within_show = track.show
                                       .tracks
                                       .joins(:songs)
                                       .where(songs: { id: song.id })
                                       .where("tracks.set <> ?", "S")
                                       .where("tracks.position < ?", track.position)
                                       .order("tracks.position DESC")

    # Only return within-show performance if current show has audio
    if track.show.audio_status != "missing" && previous_tracks_within_show.exists?
      return previous_tracks_within_show.first
    end

    previous_tracks.first
  end

  def find_next_performance_with_audio(song, track)
    next_tracks = Track.joins(:show, :songs)
                       .where(songs: { id: song.id })
                       .where("tracks.set <> ?", "S")
                       .where("shows.date > ?", track.show.date)
                       .where.not(shows: { audio_status: "missing" })
                       .where(shows: { exclude_from_stats: false })
                       .order("shows.date ASC, tracks.position ASC")

    next_tracks_within_show = track.show
                                   .tracks
                                   .joins(:songs)
                                   .where(songs: { id: song.id })
                                   .where("tracks.set <> ?", "S")
                                   .where("tracks.position > ?", track.position)
                                   .order("tracks.position ASC")

    # Only return within-show performance if current show has audio
    if track.show.audio_status != "missing" && next_tracks_within_show.exists?
      return next_tracks_within_show.first
    end

    next_tracks.first
  end

  def calculate_gap(start_date, end_date)
    return nil if start_date.nil? || end_date.nil?
    return 0 if start_date == end_date

    # Count shows between the dates (exclusive of start and end dates)
    # Then add 1 to match PhishNet's inclusive counting methodology
    gap = Show.where(date: start_date.next_day..end_date.prev_day)
              .where(exclude_from_stats: false)
              .count
    gap + 1
  end

  def calculate_gap_with_audio(start_date, end_date)
    return nil if start_date.nil? || end_date.nil?
    return 0 if start_date == end_date

    # Count shows with audio between the dates (exclusive of start and end dates)
    # Then add 1 to match PhishNet's inclusive counting methodology
    gap = Show.where(date: start_date.next_day..end_date.prev_day)
              .where.not(audio_status: "missing")
              .where(exclude_from_stats: false)
              .count
    gap + 1
  end

  def build_slug(track)
    return nil unless track
    "#{track.show.date}/#{track.slug}"
  end

  def log_info(message)
    Rails.logger.info(message) unless Rails.env.test?
  end
end
