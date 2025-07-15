class AddExcludeFromPerformanceGapsToTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :tracks, :exclude_from_performance_gaps, :boolean, default: false
  end
end
