require "google/apis/sheets_v4"

class GoogleSpreadsheetFetcher < ApplicationService
  param :spreadsheet_id
  param :range
  option :opts, optional: true, default: -> { {} }

  def call
    service.authorization = GoogleSheetsAuthorizer.call
    fetch_data
  end

  private

  def fetch_data
    return response unless has_headers
    column_headers = response.shift
    response.map do |row|
      {}.tap do |hash|
        column_headers.each_with_index do |title, idx|
          hash[title] = row[idx]
        end
      end
    end
  end

  def service
    @service ||= Google::Apis::SheetsV4::SheetsService.new
  end

  def response
    @response ||= service.get_spreadsheet_values(spreadsheet_id, range).values.to_a
  end

  def has_headers
    @has_headers = opts[:headers].nil? ? true : opts[:headers]
  end
end
