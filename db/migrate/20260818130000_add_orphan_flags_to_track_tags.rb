class AddOrphanFlagsToTrackTags < ActiveRecord::Migration[8.0]
  def change
    add_column :track_tags, :orphaned_at, :datetime
    add_column :track_tags, :orphan_reason, :string

    add_index :track_tags, :orphaned_at, where: "orphaned_at IS NOT NULL"
  end
end
