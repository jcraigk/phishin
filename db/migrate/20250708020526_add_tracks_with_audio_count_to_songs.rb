class AddTracksWithAudioCountToSongs < ActiveRecord::Migration[8.0]
  def up
    add_column :songs, :tracks_with_audio_count, :integer, default: 0

    # Add index for performance
    add_index :songs, :tracks_with_audio_count

    # Populate the counter cache
    populate_tracks_with_audio_counts
  end

  def down
    remove_index :songs, :tracks_with_audio_count
    remove_column :songs, :tracks_with_audio_count
  end

  private

  def populate_tracks_with_audio_counts
    # Populate song counter caches
    execute <<-SQL
      UPDATE songs
      SET tracks_with_audio_count = (
        SELECT COUNT(*)
        FROM songs_tracks
        INNER JOIN tracks ON songs_tracks.track_id = tracks.id
        WHERE songs_tracks.song_id = songs.id
        AND tracks.audio_status = 'complete'
      )
    SQL
  end
end
