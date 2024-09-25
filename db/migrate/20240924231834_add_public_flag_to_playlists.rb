class AddPublicFlagToPlaylists < ActiveRecord::Migration[7.2]
  def change
    add_column :playlists, :public, :boolean, default: false
  end
end
