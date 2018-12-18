# frozen_string_literal: true
namespace :songs do
  desc 'Sync song.tracks_count'
  task sync_tracks_count: :environment do
    Song.find_each do |song|
      song.update(tracks_count: song.tracks.count)
      print '.'
    end
  end
end
