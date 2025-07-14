class AddIndexesForYearsApiOptimization < ActiveRecord::Migration[7.2]
  def change
    add_index :shows, [ :published, :date ], name: 'index_shows_on_published_and_date'

    add_index :shows, [ :published, :audio_status, :venue_id ], name: 'index_shows_on_published_audio_venue'

    add_index :shows, "date_part('year', date)", name: 'index_shows_on_year_extracted'

    add_index :shows, [ :published, :duration ], name: 'index_shows_on_published_duration'
  end
end
