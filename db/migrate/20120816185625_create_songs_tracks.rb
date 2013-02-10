class CreateSongsTracks < ActiveRecord::Migration
  def change
    create_table :songs_tracks do |t|
      t.references  :song
      t.references  :track
    end
    
    add_index :songs_tracks, :song_id
    add_index :songs_tracks, :track_id
  end
end