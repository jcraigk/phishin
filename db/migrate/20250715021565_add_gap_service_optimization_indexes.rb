class AddGapServiceOptimizationIndexes < ActiveRecord::Migration[8.0]
  def change
    # Optimizes: Show.where(date: range).where("performance_gap_value > 0").with_audio
    add_index :shows, [ :date, :performance_gap_value, :audio_status ],
              name: 'index_shows_on_date_performance_gap_audio'

    # Optimizes the base query in find_performance method
    add_index :shows, [ :performance_gap_value, :audio_status, :date ],
              name: 'index_shows_on_performance_gap_audio_date'

    # Covers: tracks.set <> 'S' AND exclude_from_performance_gaps = false
    add_index :tracks, [ :set, :exclude_from_performance_gaps, :show_id, :position ],
              name: 'index_tracks_on_set_exclude_show_position'

    # Optimize within-show track lookups in find_tracks_within_show and find_tracks_different_unit
    add_index :tracks, [ :show_id, :set, :exclude_from_performance_gaps, :position ],
              name: 'index_tracks_on_show_set_exclude_position'

    # Partial index for shows with audio (most common case)
    # Optimizes queries when audio_required = true
    add_index :shows, [ :date, :performance_gap_value ],
              where: "audio_status IN ('complete', 'partial')",
              name: 'index_shows_with_audio_on_date_performance_gap'

    # Optimize the songs_tracks join queries with song_id
    # Covers the frequent SongsTrack.joins(track: :show).where(song:) pattern
    add_index :songs_tracks, [ :song_id, :track_id ],
              name: 'index_songs_tracks_on_song_track_optimized'
    # Note: This may be redundant with existing unique index, but ensures optimal ordering
  end
end
