class RemovePublishedFromShows < ActiveRecord::Migration[8.0]
  def change
    remove_column :shows, :published, :boolean, null: false, default: false
  end
end
