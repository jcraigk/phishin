class RemoveUniqueIdxOnTrackTags < ActiveRecord::Migration[5.2]
  def change
    remove_index :track_tags, name: :index_track_tags_on_tag_id_and_track_id
  end
end
