class AddCoverArtToShows < ActiveRecord::Migration[7.2]
  def change
    add_column :shows, :cover_art_style, :string
    add_column :shows, :cover_art_hue, :string
    add_column :shows, :cover_art_prompt, :text
    add_column :shows, :cover_art_parent_show_id, :integer
  end
end
