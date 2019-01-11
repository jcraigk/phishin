# frozen_string_literal: true
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

namespace :tagin do
  desc 'Sync data from remote spreadsheet'
  task sync: :environment do
    SPREADSHEET_ID = '1WZtJYSHvt0DSYeUtzM5h0U5c90DN9Or7ckkJD-ds-rM'

    TAGIN_TAG_NAMES.each do |tag_name|
      puts '========================'
      puts " Syncing Tag: #{tag_name}"
      puts '========================'

      range = "#{tag_name}!A1:D50"
      data = GoogleSpreadsheetFetcher.new(SPREADSHEET_ID, range).call
      TrackTagSyncService.new(tag_name, data).call
    end
  end

  desc 'Provide links to tracks based on song'
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

  desc 'Apply Costume Set tag to shows and tracks'
  task costume: :environment do
    tag = Tag.find_by(name: 'Costume Set')
    show_data = {
      '1994-10-31' => 'The White Album by The Beatles',
      '1996-10-31' => 'Remain In Light by Talking Heads',
      '1998-10-31' => 'Loaded by The Velvet Underground ',
      '1998-11-02' => 'Dark Side of the Moon by Pink Floyd',
      '2009-10-31' => 'Exile on Main St. by The Rolling Stones',
      '2010-10-31' => 'Waiting for Columbus by Little Feat',
      '2014-10-31' => 'Chilling, Thrilling Sounds of the Haunted House by Disneyland/Phish',
      '2016-10-31' => 'The Rise and Fall of Ziggy Stardust and the Spiders From Mars by David Bowie',
      '2018-10-31' => 'i Rokk by Kasvot Växt (Phish)'
    }
    # Exclude standard songs surrounding 1998-11-02 Dark Side of the Moon
    blacklist_track_ids = [17952, 17953, 17954, 17955, 17956, 17966]

    # Clear existing
    ShowTag.where(tag_id: tag.id).destroy_all
    TrackTag.where(tag_id: tag.id).destroy_all

    # Apply show and track tags
    show_data.each do |date, notes|
      show = Show.find_by(date: date)
      ShowTag.create(show: show, tag: tag, notes: notes)
      Track.where(show_id: show.id, set: '2')
           .where
           .not(id: blacklist_track_ids)
           .order(position: :asc)
           .each do |track|
        TrackTag.create(track: track, tag: tag, notes: notes)
        puts track.url
      end
    end
  end
end
