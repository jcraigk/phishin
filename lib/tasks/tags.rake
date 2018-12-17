# frozen_string_literal: true
namespace :tags do
  desc 'Find and destroy orphan TrackTags'
  task destroy_orphan_track_tags: :environment do
    num_orphans = 0
    TrackTag.find_each do |track_tag|
      next if Track.where(id: track_tag.track_id).first
      num_orphans += 1
      track_tag.destroy
    end
    puts "Total orphaned TrackTags destroyed: #{num_orphans}"
  end

  desc 'Find and destroy orphan ShowTags'
  task destroy_orphan_show_tags: :environment do
    num_orphans = 0
    ShowTag.find_each do |show_tag|
      next if Track.where(id: show_tag.show_id).first
      num_orphans += 1
      show_tag.destroy
    end
    puts "Total orphaned ShowTags destroyed: #{num_orphans}"
  end

  desc 'Sync track_counts and show_counts on each tag'
  task sync_counts: :environment do
    Tag.find_each do |tag|
      tag.shows_count = ShowTag.where(tag_id: tag.id).count
      tag.tracks_count = TrackTag.where(tag_id: tag.id).count
      tag.save
      puts "Tag #{tag.name} => shows: #{tag.shows_count}, tracks: #{tag.tracks_count}"
    end
  end
end
