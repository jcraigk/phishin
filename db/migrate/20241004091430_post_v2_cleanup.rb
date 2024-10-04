class PostV2Cleanup < ActiveRecord::Migration[7.2]
  def change
    drop_table :playlist_bookmarks

    remove_column :songs, :lyrical_excerpt, :string
    remove_column :songs, :instrumental, :boolean
    remove_column :tracks, :waveform_max, :integer
  end
end
