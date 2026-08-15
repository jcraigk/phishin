require "rails_helper"

# No example here reaches the Google Sheets API. GoogleSpreadsheetFetcher is
# stubbed at the class level in every example, which keeps the google-api-client
# stack and its OAuth credentials out of the picture entirely.
RSpec.describe TaginSyncService do
  before do
    allow(GoogleSpreadsheetFetcher).to receive(:call).and_return([])
    allow(TrackTagSyncService).to receive(:call)
    allow(Rails.cache).to receive(:clear)
  end

  it "syncs every tagin tag" do
    described_class.call
    expect(GoogleSpreadsheetFetcher).to have_received(:call).exactly(TAGIN_TAGS.size).times
    expect(TrackTagSyncService).to have_received(:call).exactly(TAGIN_TAGS.size).times
  end

  it "clears the cache" do
    described_class.call
    expect(Rails.cache).to have_received(:clear)
  end

  it "requests each tag's own sheet range" do
    described_class.call
    expect(GoogleSpreadsheetFetcher)
      .to have_received(:call)
      .with(ENV["TAGIN_GSHEET_ID"], "#{TAGIN_TAGS.first}!A1:G5000", headers: true)
  end

  it "hands the fetched rows to the tag sync service" do
    rows = [ { "URL" => "http://phish.in/1997-11-17/ghost" } ]
    allow(GoogleSpreadsheetFetcher).to receive(:call).and_return(rows)
    described_class.call
    expect(TrackTagSyncService).to have_received(:call).with(TAGIN_TAGS.first, rows)
  end

  it "reports progress" do
    seen = []
    described_class.call(progress: ->(tag, index, total) { seen << [ tag, index, total ] })
    expect(seen.size).to eq(TAGIN_TAGS.size)
  end

  it "reports the first tag at index zero" do
    seen = []
    described_class.call(progress: ->(tag, index, total) { seen << [ tag, index, total ] })
    expect(seen.first).to eq([ TAGIN_TAGS.first, 0, TAGIN_TAGS.size ])
  end

  it "returns a result per tag" do
    expect(described_class.call.size).to eq(TAGIN_TAGS.size)
  end

  it "marks each synced tag as ok" do
    expect(described_class.call.map { |result| result[:status] }.uniq).to eq([ "ok" ])
  end

  context "when one tag's sheet fails" do
    before do
      allow(GoogleSpreadsheetFetcher).to receive(:call).and_call_original
      allow(GoogleSpreadsheetFetcher)
        .to receive(:call)
        .with(anything, /\A#{Regexp.escape(TAGIN_TAGS.first)}!/, any_args)
        .and_raise(StandardError, "sheet tab missing")
      TAGIN_TAGS.drop(1).each do |tag_name|
        allow(GoogleSpreadsheetFetcher)
          .to receive(:call)
          .with(anything, /\A#{Regexp.escape(tag_name)}!/, any_args)
          .and_return([])
      end
    end

    it "still syncs the remaining tags" do
      described_class.call
      expect(TrackTagSyncService).to have_received(:call).exactly(TAGIN_TAGS.size - 1).times
    end

    it "records the failure against the tag" do
      result = described_class.call.find { |item| item[:tag] == TAGIN_TAGS.first }
      expect(result).to eq(tag: TAGIN_TAGS.first, status: "failed", error: "sheet tab missing")
    end

    it "still clears the cache" do
      described_class.call
      expect(Rails.cache).to have_received(:clear)
    end
  end

  context "when every tag fails" do
    before do
      allow(GoogleSpreadsheetFetcher)
        .to receive(:call)
        .and_raise(StandardError, "No valid credentials found and not in development environment")
    end

    it "raises so the caller can surface the failure" do
      expect { described_class.call }.to raise_error(
        TaginSyncService::SyncFailed,
        /No valid credentials found/
      )
    end

    it "names every failed tag in the message" do
      expect { described_class.call }
        .to raise_error(TaginSyncService::SyncFailed, /all #{TAGIN_TAGS.size} tags/)
    end

    it "does not clear the cache" do
      expect { described_class.call }.to raise_error(TaginSyncService::SyncFailed)
      expect(Rails.cache).not_to have_received(:clear)
    end
  end
end
