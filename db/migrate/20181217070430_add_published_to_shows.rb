class AddPublishedToShows < ActiveRecord::Migration[5.2]
  def change
    add_column :shows, :published, :boolean, null: false, default: false
  end
end
