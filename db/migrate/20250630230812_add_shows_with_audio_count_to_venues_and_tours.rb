class AddShowsWithAudioCountToVenuesAndTours < ActiveRecord::Migration[8.0]
  def up
    add_column :venues, :shows_with_audio_count, :integer, default: 0
    add_column :tours, :shows_with_audio_count, :integer, default: 0

    # Add indexes for performance
    add_index :venues, :shows_with_audio_count
    add_index :tours, :shows_with_audio_count

    # Populate the counter caches
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
    # Populate venue counter caches
    execute <<-SQL
      UPDATE venues
      SET shows_with_audio_count = (
        SELECT COUNT(*)
        FROM shows
        WHERE shows.venue_id = venues.id
        AND shows.audio_status IN ('complete', 'partial')
      )
    SQL

    # Populate tour counter caches
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
