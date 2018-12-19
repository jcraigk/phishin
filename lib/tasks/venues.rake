# frozen_string_literal: true
namespace :venues do
  desc 'Find venues that have the same geocode'
  task dupe_geocodes: :environment do
    num = 0
    Venue.find_each do |venue|
      other_venue =
        Venue.where(
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
end
