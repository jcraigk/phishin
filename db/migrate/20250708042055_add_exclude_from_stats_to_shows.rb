class AddExcludeFromStatsToShows < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :exclude_from_stats, :boolean, default: false, null: false
  end
end
