class AddPublishedFlagToShows < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :published, :boolean, default: true, null: false
  end
end
