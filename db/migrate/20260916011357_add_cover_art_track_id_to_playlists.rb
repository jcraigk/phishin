class AddCoverArtTrackIdToPlaylists < ActiveRecord::Migration[8.1]
  def up
    add_column :playlists, :cover_art_track_id, :integer

    execute <<~SQL
      UPDATE playlists
      SET cover_art_track_id = (
        SELECT track_id FROM playlist_tracks
        WHERE playlist_tracks.playlist_id = playlists.id
        ORDER BY position ASC
        LIMIT 1
      )
    SQL
  end

  def down
    remove_column :playlists, :cover_art_track_id
  end
end
