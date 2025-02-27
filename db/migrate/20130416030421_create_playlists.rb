class CreatePlaylists < ActiveRecord::Migration
  def change
    create_table :playlists do |t|
      t.integer :user_id
      t.string :name
      t.string :slug
      t.timestamps
    end
    create_table :playlist_tracks do |t|
      t.integer :playlist_id
      t.integer :track_id
      t.integer :position
    end
    add_index :playlists, :user_id
    add_index :playlists, :name
    add_index :playlists, :slug
    add_index :playlist_tracks, :playlist_id
    add_index :playlist_tracks, :track_id
    add_index :playlist_tracks, :position
  end
end
