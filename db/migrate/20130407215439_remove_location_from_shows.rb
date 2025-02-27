class RemoveLocationFromShows < ActiveRecord::Migration
  def change
    remove_column :shows, :location
  end
end
