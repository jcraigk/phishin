class CreateSongs < ActiveRecord::Migration
  def change
    create_table :songs do |t|
      t.string        :title
      t.string        :slug
      t.integer       :tracks_count, default: 0
      t.integer       :alias_for
      t.timestamps
    end

    add_index :songs, :title
  end
end
