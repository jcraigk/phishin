class AddDurationToShows < ActiveRecord::Migration
  def change
    add_column :shows, :duration, :integer, null: false, default: 0

    add_index :shows, :duration
    add_index :shows, :date
  end
end
