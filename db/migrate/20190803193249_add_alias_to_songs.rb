class AddAliasToSongs < ActiveRecord::Migration[5.2]
  def up
    add_column :songs, :alias, :string
    add_index :songs, :alias, unique: true

    # Convert all alias_for records to alias strings on their target records
    Song.where('alias_for IS NOT NULL').find_each do |alias_song|
      target_song = Song.find(alias_song.alias_for)
      target_song.update(alias: alias_song.title)
      alias_song.destroy
    end
  end

  def down
    remove_column :songs, :alias
  end
end
