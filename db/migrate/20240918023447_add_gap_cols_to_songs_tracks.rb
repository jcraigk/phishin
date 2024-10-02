class AddGapColsToSongsTracks < ActiveRecord::Migration[7.2]
  def change
    add_column :songs_tracks, :previous_performance_gap, :integer
    add_column :songs_tracks, :previous_performance_slug, :string
    add_column :songs_tracks, :next_performance_gap, :integer
    add_column :songs_tracks, :next_performance_slug, :string

    add_index :songs_tracks, :previous_performance_gap
    add_index :songs_tracks, :next_performance_gap
  end
end
