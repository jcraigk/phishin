# frozen_string_literal: true
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

namespace :tagit do
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
end
