class AddCombinesToStagedTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :staged_tracks, :combines, :jsonb, default: [], null: false
  end
end
