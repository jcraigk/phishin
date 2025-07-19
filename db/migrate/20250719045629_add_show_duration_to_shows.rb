class AddShowDurationToShows < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :show_duration, :integer
  end
end
