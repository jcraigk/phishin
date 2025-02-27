class ChangeVenues < ActiveRecord::Migration
  def change
    remove_column :venues, :vague_location
    add_column :venues, :abbrev, :string
  end
end
