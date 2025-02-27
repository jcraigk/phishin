class AddCountsToTags < ActiveRecord::Migration
  def change
    add_column :tags, :shows_count, :integer, default: 0
    add_column :tags, :tracks_count, :integer, default: 0
  end
end
