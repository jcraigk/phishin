class AddLyricalExcerptToSongs < ActiveRecord::Migration
  def change
    add_column :songs, :lyrical_excerpt, :string
  end
end
