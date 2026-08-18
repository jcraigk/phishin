require "rails_helper"

RSpec.describe GoogleSpreadsheetAppender do
  let(:sheet_service) { instance_double(Google::Apis::SheetsV4::SheetsService, "authorization=": nil) }
  let(:rows) { [ [ "https://phish.in/2025-12-31/harry-hood", "", "", "Norwegian Wood by The Beatles", "", "Imported" ] ] }

  before do
    allow(GoogleSheetsAuthorizer).to receive(:call).and_return(double)
    allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(sheet_service)
    allow(sheet_service).to receive(:append_spreadsheet_value)
  end

  it "appends the rows to the given range" do
    described_class.call("sheet-id", "Tease!A:F", rows)

    expect(sheet_service).to have_received(:append_spreadsheet_value) do |id, range, value_range, opts|
      expect(id).to eq("sheet-id")
      expect(range).to eq("Tease!A:F")
      expect(value_range.values).to eq(rows)
      expect(opts[:value_input_option]).to eq("USER_ENTERED")
      expect(opts[:insert_data_option]).to eq("INSERT_ROWS")
    end
  end

  it "authorizes with the writable spreadsheets scope" do
    described_class.call("sheet-id", "Tease!A:F", rows)

    expect(GoogleSheetsAuthorizer).to have_received(:call)
      .with(scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS)
  end

  it "explains how to re-authorize when the token lacks write scope" do
    allow(sheet_service).to receive(:append_spreadsheet_value)
      .and_raise(Google::Apis::ClientError.new("PERMISSION_DENIED: Request had insufficient authentication scopes."))

    expect { described_class.call("sheet-id", "Tease!A:F", rows) }
      .to raise_error(Google::Apis::ClientError, /tagin:authorize/)
  end

  it "re-raises unrelated client errors unchanged" do
    allow(sheet_service).to receive(:append_spreadsheet_value)
      .and_raise(Google::Apis::ClientError.new("NOT_FOUND: no such spreadsheet"))

    expect { described_class.call("sheet-id", "Tease!A:F", rows) }
      .to raise_error(Google::Apis::ClientError, /NOT_FOUND/)
  end

  it "raises when given no rows" do
    expect { described_class.call("sheet-id", "Tease!A:F", []) }
      .to raise_error(ArgumentError, /no rows/i)
  end
end
