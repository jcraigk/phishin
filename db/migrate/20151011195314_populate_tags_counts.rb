class PopulateTagsCounts < ActiveRecord::Migration
  def up
    execute 'update shows set tags_count=(select count(*) from show_tags where show_id=shows.id)'
    execute 'update tracks set tags_count=(select count(*) from track_tags where track_id=tracks.id)'
  end

  def down; end
end
