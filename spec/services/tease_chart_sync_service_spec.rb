require "rails_helper"

RSpec.describe TeaseChartSyncService do
  subject(:service) { described_class.new(year: "2025") }

  let!(:tease_tag) { create(:tag, name: "Tease") }
  let!(:show) { create(:show, date: "2025-12-31") }
  let!(:yem) { create(:track, show:, title: "You Enjoy Myself", position: 1) }
  let!(:hood) { create(:track, show:, title: "Harry Hood", position: 2) }

  let(:chart_rows) do
    [ [ "Norwegian Wood", "The Beatles", "1", "2025-12-31 Hood" ] ]
  end
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
    allow(ENV).to receive(:fetch).with("PNET_API_KEY").and_return("pnet-key")
    allow(Typhoeus).to receive(:get) do |url|
      body = if url.include?("tease-chart")
               chart_html(chart_rows)
      else
               { "data" => songs }.to_json
      end
      instance_double(Typhoeus::Response, success?: true, code: 200, body:)
    end
  end

  it "proposes a tag for a chart occurrence missing from the database" do
    service.call

    expect(service.proposed_rows)
      .to eq([ { track: hood, note: "Norwegian Wood by The Beatles" } ])
  end

  it "resolves abbreviated song labels to the right track in the show" do
    service.call

    expect(service.proposed_rows.first[:track]).to eq(hood)
  end

  it "unescapes HTML entities in abbreviations" do
    expect(service.send(:song_titles)["cp"]).to eq("Crosseyed and Painless")
  end

  context "when the teased song is a Phish original" do
    let(:chart_rows) { [ [ "Meatstick", "Phish", "1", "2025-12-31 Hood" ] ] }

    it "omits the artist suffix" do
      service.call
      expect(service.proposed_rows.first[:note]).to eq("Meatstick")
    end
  end

  context "when the database already has the tease" do
    before do
      create(:track_tag, tag: tease_tag, track: hood, notes: "Norwegian Wood by The Beatles")
    end

    it "skips it" do
      service.call

      expect(service.proposed_rows).to be_empty
      expect(service.skipped_existing).to eq(1)
    end
  end

  context "when the existing tag spells the tease slightly differently" do
    let(:chart_rows) { [ [ "Tequila", "The Champs", "1", "2025-12-31 Hood" ] ] }

    before do
      create(:track_tag, tag: tease_tag, track: hood, notes: "Tequilla by The Champs")
    end

    it "still proposes it, since the titles differ" do
      service.call
      expect(service.proposed_rows.size).to eq(1)
    end
  end

  context "when the show has a Tweezer sandwich and a Tweezer Reprise" do
    let(:chart_rows) { [ [ "I Feel the Earth Move", "Carole King", "1", "2025-12-31 Tweezer" ] ] }
    let!(:reprise) { create(:track, show:, title: "Tweezer Reprise", position: 3) }
    let!(:sandwich) { create(:track, show:, title: "Tweezer > Manteca > Tweezer", position: 4) }

    it "places the tease on the sandwich" do
      service.call

      expect(service.proposed_rows.first[:track]).to eq(sandwich)
    end
  end

  context "when the show has two tracks with the teased song's title" do
    let(:chart_rows) { [ [ "Buffalo Bill", "Phish", "1", "2025-12-31 Tweezer" ] ] }
    let!(:tweezer) { create(:track, show:, title: "Tweezer", position: 3) }
    let!(:tweezer2) { create(:track, show:, title: "Tweezer", position: 4) }

    it "proposes the earlier one when neither is tagged" do
      service.call
      expect(service.proposed_rows.first[:track]).to eq(tweezer)
    end

    context "when the later one already has the tease tag" do
      before { create(:track_tag, tag: tease_tag, track: tweezer2, notes: "Buffalo Bill") }

      it "treats it as covered" do
        service.call

        expect(service.proposed_rows).to be_empty
        expect(service.skipped_existing).to eq(1)
      end
    end
  end

  context "when the chart lists the same tease twice for one show" do
    let(:chart_rows) do
      [ [ "Norwegian Wood", "The Beatles", "2", "2025-12-31 Hood, 2025-12-31 Hood" ] ]
    end

    it "proposes only one tag" do
      service.call
      expect(service.proposed_rows.size).to eq(1)
    end
  end

  context "when the chart disambiguates the title with the artist" do
    let(:chart_rows) { [ [ "Fire (Ohio Players)", "Ohio Players", "1", "2025-12-31 Hood" ] ] }

    it "does not repeat the artist in the note" do
      service.call
      expect(service.proposed_rows.first[:note]).to eq("Fire by Ohio Players")
    end
  end

  context "when the parenthetical is not the artist" do
    let(:chart_rows) { [ [ "Norwegian Wood (This Bird Has Flown)", "The Beatles", "1", "2025-12-31 Hood" ] ] }

    it "keeps the parenthetical" do
      service.call
      expect(service.proposed_rows.first[:note]).to eq("Norwegian Wood (This Bird Has Flown) by The Beatles")
    end
  end

  context "when the chart has a stray number in the artist column" do
    let(:chart_rows) { [ [ "Hanky Panky", "1", "1", "2025-12-31 Hood" ] ] }

    it "omits the artist rather than writing \"by 1\"" do
      service.call
      expect(service.proposed_rows.first[:note]).to eq("Hanky Panky")
    end
  end

  context "when the chart page is served as raw bytes" do
    let(:chart_rows) do
      [ [ "Entrance of the Gladiators", "Julius Fučík", "1", "2025-12-31 Hood" ] ]
    end

    it "decodes accented characters instead of double-encoding them" do
      service.call
      expect(service.proposed_rows.first[:note]).to eq("Entrance of the Gladiators by Julius Fučík")
    end
  end

  context "when the chart has irrecoverably lost characters" do
    let(:chart_rows) { [ [ "Single Ladies (Put a Ring on It)", "Beyonc�", "1", "2025-12-31 Hood" ] ] }

    it "substitutes the known correct spelling" do
      service.call
      expect(service.proposed_rows.first[:note]).to eq("Single Ladies (Put a Ring on It) by Beyoncé")
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
    it "does not create tags during a dry run" do
      expect { service.call }.not_to change(TrackTag, :count)
    end

    it "creates tease tags when applying" do
      expect { described_class.call(year: "2025", apply: true) }
        .to change(TrackTag, :count).by(1)
      track_tag = TrackTag.last
      expect(track_tag.track).to eq(hood)
      expect(track_tag.tag).to eq(tease_tag)
      expect(track_tag.notes).to eq("Norwegian Wood by The Beatles")
    end
  end
end
