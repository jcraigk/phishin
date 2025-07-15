class AddPerformanceGapValueToShows < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :performance_gap_value, :integer, default: 1
  end
end
