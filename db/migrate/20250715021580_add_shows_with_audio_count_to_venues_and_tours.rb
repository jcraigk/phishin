class AddShowsWithAudioCountToVenuesAndTours < ActiveRecord::Migration[8.0]
  def up
    add_column :venues, :shows_with_audio_count, :integer, default: 0
    add_column :tours, :shows_with_audio_count, :integer, default: 0

    add_index :venues, :shows_with_audio_count
    add_index :tours, :shows_with_audio_count

    populate_shows_with_audio_counts
  end

  def down
    remove_index :venues, :shows_with_audio_count
    remove_index :tours, :shows_with_audio_count
    remove_column :venues, :shows_with_audio_count
    remove_column :tours, :shows_with_audio_count
  end

  private

  def populate_shows_with_audio_counts
    execute <<-SQL
      UPDATE venues
      SET shows_with_audio_count = (
        SELECT COUNT(*)
        FROM shows
        WHERE shows.venue_id = venues.id
        AND shows.audio_status IN ('complete', 'partial')
      )
    SQL

    execute <<-SQL
      UPDATE tours
      SET shows_with_audio_count = (
        SELECT COUNT(*)
        FROM shows
        WHERE shows.tour_id = tours.id
        AND shows.audio_status IN ('complete', 'partial')
      )
    SQL
  end
end
