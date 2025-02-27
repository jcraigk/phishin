class AddVenueNameToShows < ActiveRecord::Migration[5.2]
  def change
    add_column :shows, :venue_name, :string, null: false, default: ''
  end
end
