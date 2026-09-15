class RemoveCoverArtHueAndStyleFromShows < ActiveRecord::Migration[8.1]
  def change
    remove_column :shows, :cover_art_hue, :string
    remove_column :shows, :cover_art_style, :string
  end
end
