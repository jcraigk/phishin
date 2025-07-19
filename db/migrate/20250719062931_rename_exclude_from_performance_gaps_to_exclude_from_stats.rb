class RenameExcludeFromPerformanceGapsToExcludeFromStats < ActiveRecord::Migration[8.0]
  def change
    rename_column :tracks, :exclude_from_performance_gaps, :exclude_from_stats

    remove_index :tracks, name: "index_tracks_on_set_exclude_show_position"
    remove_index :tracks, name: "index_tracks_on_show_set_exclude_position"

    add_index :tracks, [ :set, :exclude_from_stats, :show_id, :position ],
              name: "index_tracks_on_set_exclude_show_position"
    add_index :tracks, [ :show_id, :set, :exclude_from_stats, :position ],
              name: "index_tracks_on_show_set_exclude_position"
  end
end
