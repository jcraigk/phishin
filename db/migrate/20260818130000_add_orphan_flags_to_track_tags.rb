# A timestamped tag describes a moment in a track's audio. When an operation
# changes that audio in a way the offset cannot be mapped through - the moment
# is trimmed away, or the file is replaced wholesale - the row is KEPT with its
# original numbers and flagged here instead of being deleted or clamped to a
# boundary it never described.
#
# The numbers stay untouched on purpose: they are the only surviving evidence of
# what the tag meant, and an admin resolving the orphan needs them.
class AddOrphanFlagsToTrackTags < ActiveRecord::Migration[8.0]
  def change
    add_column :track_tags, :orphaned_at, :datetime
    add_column :track_tags, :orphan_reason, :string

    # The dashboard orphan queue lists every flagged row newest first, and the
    # flagged rows are a tiny fraction of 3,448 timestamped tags, so a partial
    # index keeps the queue cheap without carrying the other 99% of the table.
    add_index :track_tags, :orphaned_at, where: "orphaned_at IS NOT NULL"
  end
end
