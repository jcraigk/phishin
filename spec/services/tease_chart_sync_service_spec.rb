require "rails_helper"

RSpec.describe TeaseChartSyncService do
  subject(:service) { described_class.new(year: "2025") }

  let!(:show) { create(:show, date: "2025-12-31") }
  let!(:yem) { create(:track, show:, title: "You Enjoy Myself", position: 1) }
  let!(:hood) { create(:track, show:, title: "Harry Hood", position: 2) }

  let(:chart_rows) do
    [ [ "Norwegian Wood", "The Beatles", "1", "2025-12-31 Hood" ] ]
  end
  let(:sheet_rows) { [] }
  let(:songs) do
    [
      { "song" => "Harry Hood", "abbr" => "Hood" },
      { "song" => "You Enjoy Myself", "abbr" => "YEM" },
      { "song" => "Crosseyed and Painless", "abbr" => "C&amp;P" }
    ]
  end

  def chart_html(rows)
    body = rows.map { |r| "<tr>#{r.map { |c| "<td>#{c}</td>" }.join}</tr>" }.join
    "<html><body><table><tr><th>Song Teased</th></tr>#{body}</table></body></html>"
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TAGIN_GSHEET_ID").and_return("sheet-id")
    allow(ENV).to receive(:fetch).with("PNET_API_KEY").and_return("pnet-key")
    allow(GoogleSpreadsheetFetcher).to receive(:call).and_return(sheet_rows)
    allow(GoogleSpreadsheetAppender).to receive(:call)
    allow(Typhoeus).to receive(:get) do |url|
      body = if url.include?("tease-chart")
               chart_html(chart_rows)
      else
               { "data" => songs }.to_json
      end
      instance_double(Typhoeus::Response, success?: true, code: 200, body:)
    end
  end

  it "proposes a row for a chart occurrence missing from the sheet" do
    service.call

    expect(service.proposed_rows).to eq([
      [ "https://phish.in/2025-12-31/#{hood.slug}", "", "", "Norwegian Wood by The Beatles", "", described_class::DEV_NOTE ]
    ])
  end

  it "resolves abbreviated song labels to the right track in the show" do
    service.call

    expect(service.proposed_rows.first.first).to include(hood.slug)
    expect(service.proposed_rows.first.first).not_to include(yem.slug)
  end

  it "unescapes HTML entities in abbreviations" do
    expect(service.send(:song_titles)["cp"]).to eq("Crosseyed and Painless")
  end

  context "when the teased song is a Phish original" do
    let(:chart_rows) { [ [ "Meatstick", "Phish", "1", "2025-12-31 Hood" ] ] }

    it "omits the artist suffix" do
      service.call
      expect(service.proposed_rows.first[3]).to eq("Meatstick")
    end
  end

  context "when the sheet already lists the tease" do
    let(:sheet_rows) do
      [ { "URL" => "https://phish.in/2025-12-31/#{hood.slug}", "Notes" => "Norwegian Wood by The Beatles" } ]
    end

    it "skips it" do
      service.call

      expect(service.proposed_rows).to be_empty
      expect(service.skipped_existing).to eq(1)
    end
  end

  context "when the sheet spells the tease slightly differently" do
    let(:chart_rows) { [ [ "Tequila", "The Champs", "1", "2025-12-31 Hood" ] ] }
    let(:sheet_rows) do
      [ { "URL" => "https://phish.in/2025-12-31/#{hood.slug}", "Notes" => "Tequilla by The Champs" } ]
    end

    it "still proposes it, since the titles differ" do
      service.call
      expect(service.proposed_rows.size).to eq(1)
    end
  end

  context "when the chart lists the same tease twice for one show" do
    let(:chart_rows) do
      [ [ "Norwegian Wood", "The Beatles", "2", "2025-12-31 Hood, 2025-12-31 Hood" ] ]
    end

    it "proposes only one row" do
      service.call
      expect(service.proposed_rows.size).to eq(1)
    end
  end

  context "when the chart disambiguates the title with the artist" do
    let(:chart_rows) { [ [ "Fire (Ohio Players)", "Ohio Players", "1", "2025-12-31 Hood" ] ] }

    it "does not repeat the artist in the note" do
      service.call
      expect(service.proposed_rows.first[3]).to eq("Fire by Ohio Players")
    end
  end

  context "when the parenthetical is not the artist" do
    let(:chart_rows) { [ [ "Norwegian Wood (This Bird Has Flown)", "The Beatles", "1", "2025-12-31 Hood" ] ] }

    it "keeps the parenthetical" do
      service.call
      expect(service.proposed_rows.first[3]).to eq("Norwegian Wood (This Bird Has Flown) by The Beatles")
    end
  end

  context "when the chart has a stray number in the artist column" do
    let(:chart_rows) { [ [ "Hanky Panky", "1", "1", "2025-12-31 Hood" ] ] }

    it "omits the artist rather than writing \"by 1\"" do
      service.call
      expect(service.proposed_rows.first[3]).to eq("Hanky Panky")
    end
  end

context "when the chart page is served as raw bytes" do
  let(:chart_rows) do
    [ [ "Entrance of the Gladiators", "Julius Fu\u010D\u00EDk", "1", "2025-12-31 Hood" ] ]
  end

  it "decodes accented characters instead of double-encoding them" do
    service.call
    expect(service.proposed_rows.first[3]).to eq("Entrance of the Gladiators by Julius Fu\u010D\u00EDk")
  end
end

context "when the chart has irrecoverably lost characters" do
  let(:chart_rows) { [ [ "Single Ladies (Put a Ring on It)", "Beyonc\uFFFD", "1", "2025-12-31 Hood" ] ] }

  it "substitutes the known correct spelling" do
    service.call
    expect(service.proposed_rows.first[3]).to eq("Single Ladies (Put a Ring on It) by Beyonc\u00E9")
  end
end

context "when the chart lists no song label" do
    let(:chart_rows) { [ [ "Norwegian Wood", "The Beatles", "1", "2025-12-31" ] ] }

    it "records it as unmatched" do
      service.call

      expect(service.proposed_rows).to be_empty
      expect(service.unmatched.first[:reason]).to eq("chart lists no song")
    end
  end

  context "when the show is not on phish.in" do
    let(:chart_rows) { [ [ "Norwegian Wood", "The Beatles", "1", "1988-05-01 Hood" ] ] }

    it "records it as unmatched" do
      svc = described_class.new(all: true)
      svc.call

      expect(svc.proposed_rows).to be_empty
      expect(svc.unmatched.first[:reason]).to eq("no show on phish.in")
    end
  end

  describe "scoping" do
    let(:chart_rows) do
      [ [ "Norwegian Wood", "The Beatles", "2", "2025-12-31 Hood, 2019-07-04 Hood" ] ]
    end

    it "only considers occurrences within the given year" do
      service.call
      expect(service.proposed_rows.size).to eq(1)
    end

    it "requires a scope option" do
      expect { described_class.call }.to raise_error(ArgumentError, /YEAR/)
    end
  end

  describe "applying" do
    it "does not write during a dry run" do
      service.call
      expect(GoogleSpreadsheetAppender).not_to have_received(:call)
    end

    it "appends proposed rows when applying" do
      described_class.call(year: "2025", apply: true)

      expect(GoogleSpreadsheetAppender).to have_received(:call)
        .with("sheet-id", described_class::APPEND_RANGE, anything)
    end
  end
end
