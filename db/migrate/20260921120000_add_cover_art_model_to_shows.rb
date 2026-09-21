class AddCoverArtModelToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :cover_art_model, :string
  end
end
