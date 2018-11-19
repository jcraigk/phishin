# frozen_string_literal: true
namespace :venues do
  desc 'Find venues that have the same geocode'
  task dupe_geocodes: :environment do
    num = 0
    Venue.relevant.each do |venue|
      other_venue =
        Venue.relevant
             .where(
               'id != ? and latitude = ? and longitude = ?',
               venue.id,
               venue.latitude,
               venue.longitude
             ).first
      next if other_venue.nil?

      num += 1
      puts "#{num}: #{other_venue.id} / #{venue.id}"
    end
  end

  desc 'Update shows_count cache'
  task sync_shows_count: :environment do
    Venue.find_each do |venue|
      shows_count = Show.avail.where(venue_id: venue.id).count
      puts "#{venue.id}: #{shows_count}"
      venue.update_attributes(shows_count: shows_count)
    end
  end
end
