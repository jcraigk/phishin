class AddTracksCountToPlaylists < ActiveRecord::Migration[7.0]
  def change
    add_column :playlists, :tracks_count, :integer, default: 0

    reversible do |dir|
      dir.up do
        Playlist.find_each do |playlist|
          Playlist.reset_counters(playlist.id, :playlist_tracks)
        end
      end
    end
  end
end
