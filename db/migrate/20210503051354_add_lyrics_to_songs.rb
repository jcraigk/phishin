class AddLyricsToSongs < ActiveRecord::Migration[6.1]
  def change
    add_column :songs, :lyrics, :text
    add_column :songs, :artist, :string
    add_column :songs, :instrumental, :boolean, default: false, null: false
  end
end
