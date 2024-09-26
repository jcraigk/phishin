class AddDurationToPlaylistTracks < ActiveRecord::Migration[7.2]
  def change
    add_column :playlist_tracks, :duration, :integer

    reversible do |dir|
      dir.up do

        # Assign durations
        PlaylistTrack.includes(:track).find_each do |pt|
          pt.send(:assign_duration)
          pt.save!
        end

        # Destroy invalid playlists
        Playlist.where('tracks_count < ?', 2).destroy_all
      end
    end
  end
end
