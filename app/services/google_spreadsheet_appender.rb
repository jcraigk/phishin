require "google/apis/sheets_v4"

class GoogleSpreadsheetAppender < ApplicationService
  param :spreadsheet_id
  param :range
  param :rows

  def call
    raise ArgumentError, "Cannot append with no rows" if rows.blank?

    service.authorization = GoogleSheetsAuthorizer.call(scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS)
    append
  rescue Google::Apis::ClientError => e
    raise unless e.message.to_s.include?("insufficient authentication scopes")
    raise Google::Apis::ClientError.new(SCOPE_ERROR, status_code: e.status_code)
  end

  SCOPE_ERROR = <<~MSG.freeze
    The stored GOOGLE_SPREADSHEET_CREDS refresh token is read-only.
    Run GoogleSheetsAuthorizer.call(scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
    force_interactive: true) in a local console, then set the printed JSON as
    GOOGLE_SPREADSHEET_CREDS (locally and in production) before appending.
  MSG

  private

  def append
    service.append_spreadsheet_value(
      spreadsheet_id,
      range,
      Google::Apis::SheetsV4::ValueRange.new(values: rows),
      value_input_option: "USER_ENTERED",
      insert_data_option: "INSERT_ROWS"
    )
  end

  def service
    @service ||= Google::Apis::SheetsV4::SheetsService.new
  end
end
