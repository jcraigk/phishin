class AddAltTitleToSongs < ActiveRecord::Migration
  def change
    add_column :songs, :alt_title, :string
    add_index :songs, :alt_title
  end
end
