class MigrateIncompleteToAudioStatus < ActiveRecord::Migration[8.0]
  def up
    # Update shows with incomplete: true to have audio_status: 'partial'
    execute <<-SQL
      UPDATE shows
      SET audio_status = 'partial'
      WHERE incomplete = true AND audio_status = 'complete'
    SQL

    # Remove the incomplete column
    remove_column :shows, :incomplete
  end

  def down
    # Add the incomplete column back
    add_column :shows, :incomplete, :boolean, default: false

    # Restore incomplete flag based on audio_status
    execute <<-SQL
      UPDATE shows
      SET incomplete = true
      WHERE audio_status = 'partial'
    SQL
  end
end
