# frozen_string_literal: true
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

namespace :tagin do
  desc 'Sync data from remote spreadsheet'
  task sync: :environment do
    TAGS = [
      'Acapella',
      'Acoustic'
    ].freeze
    SPREADSHEET_ID = '1WZtJYSHvt0DSYeUtzM5h0U5c90DN9Or7ckkJD-ds-rM'

    TAGS.each do |tag_name|
      puts '========================'
      puts " Syncing Tag: #{tag_name}"
      puts '========================'

      range = "#{tag_name}!A1:D50"
      data = GoogleSpreadsheetFetcher.new(SPREADSHEET_ID, range).call
      TrackTagSyncService.new(tag_name, data).call
    end
  end

  desc 'Provide links to all acapella tracks based on song'
  task songs: :environment do
    SONG_TITLES = [
      'The Haunted House',
      'The Very Long Fuse',
      'The Dogs',
      'Timber',
      'Your Pet Cat',
      'Shipwreck',
      'The Unsafe Bridge',
      'The Chinese Water Torture',
      'The Birds',
      'Martian Monster',
      'We Are Come to Outlive Our Brains'
    ].freeze

    SONG_TITLES.each do |title|
      song = Song.find_by!(title: title)
      song.tracks.find_each do |track|
        puts track.url
      end
    end
  end
end
