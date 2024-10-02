class TranslatePlaylistBookmarksToLikes < ActiveRecord::Migration[7.2]
  def change
    reversible do |dir|
      dir.up do
        PlaylistBookmark.find_each do |pb|
          likable = Playlist.find_by(id: pb.playlist_id)
          next unless likable
          Like.create!(likable:, user_id: pb.user_id)

        # Skip duplicate bookmarks
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          next
        end
      end
    end
  end
end
