class AddTourIdToShows < ActiveRecord::Migration
  def change
    add_column :shows, :tour_id, :integer
    add_index :shows, :tour_id
  end

end
