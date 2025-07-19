class AddIndexesForYearsApiOptimization < ActiveRecord::Migration[8.0]
  def change
    add_index :shows, [ :audio_status, :venue_id ], name: 'index_shows_on_audio_venue'
    add_index :shows, "date_part('year', date)", name: 'index_shows_on_year_extracted'
  end
end
