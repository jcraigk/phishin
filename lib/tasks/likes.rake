# frozen_string_literal: true
namespace :likes do
  desc 'Find and destroy orphan Likes'
  task destroy_orphans: :environment do
    num_orphans = 0
    Like.find_each do |like|
      if like.likable_type == 'Track'
        next if Track.find_by(id: like.likable_id)
        num_orphans += 1
        like.destroy
      elsif like.likable_type == 'Show'
        next if Show.unscoped.find_by(id: like.likable_id)
        num_orphans += 1
        like.destroy
      end
    end
    puts "Total orphaned Likes destroyed: #{num_orphans}"
  end
end
