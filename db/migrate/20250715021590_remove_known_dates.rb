class RemoveKnownDates < ActiveRecord::Migration[8.0]
  def change
    drop_table :known_dates
  end
end
