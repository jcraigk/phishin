# frozen_string_literal: true
namespace :songs do
  desc 'Sync song.tracks_count'
  task sync_tracks_count: :environment do
    Song.all.each do |song|
      count = song.tracks.size
      song.update_attributes(tracks_count: count)
      puts "#{song.title} has #{count} tracks"
    end
  end
end
