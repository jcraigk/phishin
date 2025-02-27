class RemoveMissingFromShows < ActiveRecord::Migration[5.2]
  def change
    remove_column :shows, :missing, :boolean
  end
end
