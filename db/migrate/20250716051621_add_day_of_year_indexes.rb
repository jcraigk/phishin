class AddDayOfYearIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add index for month extraction - used in day_of_year queries
    add_index :shows, "extract(month from date)", name: 'index_shows_on_month_extracted'

    # Add index for day extraction - used in day_of_year queries
    add_index :shows, "extract(day from date)", name: 'index_shows_on_day_extracted'

    # Composite index for filtering by month and day
    add_index :shows, "extract(month from date), extract(day from date)",
              name: 'index_shows_on_month_day_extracted'
  end
end
