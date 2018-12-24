# frozen_string_literal: true
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

namespace :tags do
  desc 'Sync data from remote spreadsheet'
  task sync_remote: :environment do
    spreadsheet_id = '1WZtJYSHvt0DSYeUtzM5h0U5c90DN9Or7ckkJD-ds-rM'
    range = 'A1:B4'

    data = GoogleSpreadsheetFetcher.new(spreadsheet_id, range).call

    binding.pry

    TagSyncService.new(data).call
  end
end
