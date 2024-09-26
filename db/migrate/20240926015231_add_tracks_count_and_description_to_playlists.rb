class AddTracksCountAndDescriptionToPlaylists < ActiveRecord::Migration[7.0]
  def change
    add_column :playlists, :tracks_count, :integer, default: 0
    add_column :playlists, :description, :text

    add_index :playlists, :tracks_count
    add_index :playlists, :likes_count
    add_index :playlists, :updated_at

    reversible do |dir|
      dir.up do
        Playlist.find_each do |playlist|
          Playlist.reset_counters(playlist.id, :playlist_tracks)
        end
      end
    end
  end
end
