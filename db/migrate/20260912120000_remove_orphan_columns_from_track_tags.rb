class RemoveOrphanColumnsFromTrackTags < ActiveRecord::Migration[8.1]
  def change
    remove_index :track_tags, :orphaned_at, name: "index_track_tags_on_orphaned_at", where: "(orphaned_at IS NOT NULL)"
    remove_column :track_tags, :orphaned_at, :datetime
    remove_column :track_tags, :orphan_reason, :string
  end
end
