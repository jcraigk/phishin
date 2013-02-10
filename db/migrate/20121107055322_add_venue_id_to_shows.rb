class AddVenueIdToShows < ActiveRecord::Migration
  def change
    add_column :shows, :venue_id, :integer
    add_index :shows, :venue_id
  end
end
