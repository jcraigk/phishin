class AddOriginalEdgesToStagedTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :staged_tracks, :original_start_s, :decimal, precision: 10, scale: 3
    add_column :staged_tracks, :original_end_s, :decimal, precision: 10, scale: 3
  end
end
