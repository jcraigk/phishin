class AddPublishedFlagToPlaylists < ActiveRecord::Migration[7.2]
  def change
    add_column :playlists, :published, :boolean, default: false
  end
end
