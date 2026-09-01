# The audit trail is gone: recovery now rests on the timestamped copies
# AudioBackup writes to tmp/audio_backups before each edit, whose filenames
# carry the show date, slug, operation and time.
class DropTrackEdits < ActiveRecord::Migration[8.0]
  def up
    drop_table :track_edits
  end

  def down
    create_table :track_edits do |t|
      t.integer :admin_job_id
      t.datetime :created_at, null: false
      t.string :operation, null: false
      t.jsonb :payload, default: {}, null: false
      t.integer :show_id, null: false
      t.integer :track_id
      t.integer :user_id
      t.index %i[show_id created_at]
      t.index %i[track_id created_at]
    end
  end
end
