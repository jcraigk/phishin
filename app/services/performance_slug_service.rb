class PerformanceSlugService < ApplicationService
  param :show

  def call
    update_slugs_for_show
  end

  private

  def update_slugs_for_show
    puts "Processing performance slugs for show #{show.date}"

    processed_songs = 0
    total_songs = 0

    # Count total songs first
    show.tracks.where.not(set: "S").each do |track|
      total_songs += track.songs.count
    end

    puts "Found #{total_songs} song performances to process (excluding soundcheck)"

    ActiveRecord::Base.transaction do
      show.tracks.where.not(set: "S").each do |track|
        track.songs.each do |song|
          song_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
          next unless song_track

          # Set previous performance slug
          previous_performance = find_previous_performance(song, track)
          previous_slug = build_slug(previous_performance)
          song_track.previous_performance_slug = previous_slug

          # Set next performance slug
          next_performance = find_next_performance(song, track)
          next_slug = build_slug(next_performance)
          song_track.next_performance_slug = next_slug

          song_track.save!
          processed_songs += 1

          puts "💾 Updated slugs for '#{song.title}' (track #{track.position}): prev=#{previous_slug || 'nil'}, next=#{next_slug || 'nil'}"
        end
      end
    end

    puts "✅ Completed processing performance slugs for show #{show.date}"
    puts "Processed #{processed_songs} song performances"
  end

  def find_previous_performance(song, track)
    previous_tracks = Track.joins(:show, :songs)
                           .where(songs: { id: song.id })
                           .where("tracks.set <> ?", "S")
                           .where("shows.date < ?", track.show.date)
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

  def build_slug(track)
    return nil unless track
    "#{track.show.date}/#{track.slug}"
  end
end
