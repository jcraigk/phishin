class AddExcerptColsToPlaylistTracks < ActiveRecord::Migration[7.2]
  def change
    add_column :playlist_tracks, :starts_at_second, :integer
    add_column :playlist_tracks, :ends_at_second, :integer
  end
end
