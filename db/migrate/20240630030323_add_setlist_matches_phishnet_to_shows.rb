class AddSetlistMatchesPhishnetToShows < ActiveRecord::Migration[7.1]
  def change
    add_column :shows, :matches_pnet, :boolean, default: false
  end
end
