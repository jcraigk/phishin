class AddAudioGapFieldsToSongsTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :songs_tracks, :previous_performance_gap_with_audio, :integer
    add_column :songs_tracks, :previous_performance_slug_with_audio, :string
    add_column :songs_tracks, :next_performance_gap_with_audio, :integer
    add_column :songs_tracks, :next_performance_slug_with_audio, :string

    add_index :songs_tracks, :previous_performance_gap_with_audio
    add_index :songs_tracks, :next_performance_gap_with_audio
  end
end
