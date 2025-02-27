class DropAliasForFromSongs < ActiveRecord::Migration[5.2]
  def change
    remove_column :songs, :alias_for, :integer
  end
end
