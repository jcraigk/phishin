namespace :tags do

  desc "Find and destroy orphan TrackTags"
  task :destroy_orphan_track_tags => :environment do
    num_orphans = 0
    TrackTag.all.each do |track_tag|
      unless track = Track.where(id: track_tag.track_id).first
        num_orphans += 1
        # track_tag.destroy
      end
    end
    puts "Total orphaned TrackTags destroyed: #{num_orphans}"
  end

  desc "Find and destroy orphan ShowTags"
  task :destroy_orphan_show_tags => :environment do
    num_orphans = 0
    ShowTag.all.each do |show_tag|
      unless track = Track.where(id: show_tag.show_id).first
        num_orphans += 1
        # track_tag.destroy
      end
    end
    puts "Total orphaned ShowTags destroyed: #{num_orphans}"
  end

end