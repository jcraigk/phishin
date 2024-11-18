namespace :db do
  desc "Backfill updated_at timestamps for touch: true associations"
  task touch_backfill: :environment do
    # Update shows via show_tags
    ShowTag.includes(:show).find_each do |show_tag|
      show_tag.show&.touch
    end

    # Update tracks via track_tags
    TrackTag.includes(:track).find_each do |track_tag|
      track_tag.track&.touch
    end

    # Update shows via tracks
    Track.includes(:show).find_each do |track|
      track.show&.touch
    end

    puts "Backfill complete! Timestamps have been updated."
  end
end
