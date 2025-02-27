class MoreIndexes < ActiveRecord::Migration[5.2]
  def change
    remove_index :playlist_tracks, name: 'index_playlist_tracks_on_position'
    add_index :playlist_tracks, %i[position playlist_id], unique: true
    remove_index :show_tags, name: 'index_show_tags_on_tag_id'
  end
end
