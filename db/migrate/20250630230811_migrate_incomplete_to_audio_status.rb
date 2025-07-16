class MigrateIncompleteToAudioStatus < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      UPDATE shows
      SET audio_status = 'partial'
      WHERE incomplete = true AND audio_status = 'complete'
    SQL

    remove_column :shows, :incomplete
  end

  def down
    add_column :shows, :incomplete, :boolean, default: false

    execute <<-SQL
      UPDATE shows
      SET incomplete = true
      WHERE audio_status = 'partial'
    SQL
  end
end
