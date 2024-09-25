class DropPlaylistBookmarks < ActiveRecord::Migration[7.2]
  def change
    drop_table :playlist_bookmarks
  end
end
