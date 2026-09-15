class ReplaceSongWithSongIdsOnStagedTracks < ActiveRecord::Migration[8.1]
  def up
    add_column :staged_tracks, :song_ids, :integer, array: true, default: [], null: false
    execute "UPDATE staged_tracks SET song_ids = ARRAY[song_id] WHERE song_id IS NOT NULL"
    remove_column :staged_tracks, :song_id
  end

  def down
    add_column :staged_tracks, :song_id, :integer
    execute "UPDATE staged_tracks SET song_id = song_ids[1] WHERE cardinality(song_ids) > 0"
    remove_column :staged_tracks, :song_ids
  end
end
