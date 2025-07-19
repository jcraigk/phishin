class RemoveShowDurationFromShows < ActiveRecord::Migration[8.0]
  def change
    remove_column :shows, :show_duration, :integer
  end
end
