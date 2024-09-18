class GapService < BaseService
  extend Dry::Initializer

  param :show

  def call
    update_song_gaps_for_show
  end

  private

  def update_song_gaps_for_show
    ActiveRecord::Base.transaction do
      show.tracks.each do |track|
        track.songs.each do |song|
          song_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)

          previous_performance = find_previous_performance(song, track)
          song_track.previous_performance_gap = calculate_gap(previous_performance&.show&.date, track.show.date)
          song_track.previous_performance_slug = build_slug(previous_performance)

          next_performance = find_next_performance(song, track)
          song_track.next_performance_gap = calculate_gap(track.show.date, next_performance&.show&.date)
          song_track.next_performance_slug = build_slug(next_performance)

          song_track.save!
        end
      end
    end
  end

  def find_previous_performance(song, track)
    previous_tracks = Track.joins(:show, :songs)
                           .where(songs: { id: song.id })
                           .where("shows.date < ?", track.show.date)
                           .order("shows.date DESC, tracks.position DESC")

    previous_tracks_within_show = track.show.tracks.joins(:songs)
                                              .where(songs: { id: song.id })
                                              .where("tracks.position < ?", track.position)
                                              .order("tracks.position DESC")

    return previous_tracks_within_show.first if previous_tracks_within_show.exists?

    previous_tracks.first
  end

  def find_next_performance(song, track)
    next_tracks = Track.joins(:show, :songs)
                       .where(songs: { id: song.id })
                       .where("shows.date > ?", track.show.date)
                       .order("shows.date ASC, tracks.position ASC")

    next_tracks_within_show = track.show.tracks.joins(:songs)
                                            .where(songs: { id: song.id })
                                            .where("tracks.position > ?", track.position)
                                            .order("tracks.position ASC")

    return next_tracks_within_show.first if next_tracks_within_show.exists?

    next_tracks.first
  end

  def calculate_gap(start_date, end_date)
    return nil if start_date.nil? || end_date.nil?
    return 0 if start_date == end_date
    num = KnownDate.where(date: start_date..end_date).count - 1
    num
  end

  def build_slug(track)
    return nil unless track
    "#{track.show.date}/#{track.slug}"
  end
end
