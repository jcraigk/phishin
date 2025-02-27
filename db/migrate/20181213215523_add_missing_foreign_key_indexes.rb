class AddMissingForeignKeyIndexes < ActiveRecord::Migration[5.2]
  def change
    add_index :songs_tracks, :song_id
    add_index :songs_tracks, :track_id
    add_index :tracks, :show_id
  end
end
