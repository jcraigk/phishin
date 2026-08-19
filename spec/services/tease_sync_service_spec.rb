require "rails_helper"

RSpec.describe TeaseSyncService do
  subject(:service) { described_class.new(date: "2025-12-31") }

  let(:show) { create(:show, date: "2025-12-31") }
  let!(:hood) { create(:track, show:, title: "Harry Hood", position: 1) }
  let!(:yem) { create(:track, show:, title: "You Enjoy Myself", position: 2) }

  let(:setlist_notes) { "Trey teased Norwegian Wood in Harry Hood. YEM contained Fuego teases." }
  let(:sheet_rows) { [] }
  let(:llm_teases) { [ { "song" => "Harry Hood", "tease" => "Norwegian Wood", "artist" => "The Beatles" } ] }
  let(:pnet_songs) { [] }
  let(:hood_url) { "https://phish.in/2025-12-31/#{hood.slug}" }

  def stub_pnet(notes, songs: pnet_songs)
    notes_body = { "data" => [ { "setlist_notes" => notes } ] }.to_json
    songs_body = { "data" => songs }.to_json
    allow(Typhoeus).to receive(:get) do |url|
      body = url.include?("/songs.json") ? songs_body : notes_body
      instance_double(Typhoeus::Response, success?: true, body:)
    end
  end

  def stub_claude(teases, leading_blocks: [])
    body = {
      "content" => leading_blocks + [ { "type" => "text", "text" => { "teases" => teases }.to_json } ],
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }.to_json
    allow(Typhoeus).to receive(:post).and_return(instance_double(Typhoeus::Response, success?: true, body:))
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TAGIN_GSHEET_ID").and_return("sheet-id")
    allow(ENV).to receive(:fetch).with("PNET_API_KEY").and_return("pnet-key")
    allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY").and_return("anthropic-key")
    allow(GoogleSpreadsheetFetcher).to receive(:call).and_return(sheet_rows)
    allow(GoogleSpreadsheetAppender).to receive(:call)
    stub_pnet(setlist_notes)
    stub_claude(llm_teases)
  end

  describe "proposed rows" do
    it "proposes a row for a tease missing from the sheet" do
      service.call

      expect(service.proposed_rows).to eq([
        [ hood_url, "", "", "Norwegian Wood by The Beatles", "", described_class::DEV_NOTE ]
      ])
    end

    context "when the tease is a Phish original" do
      let(:llm_teases) { [ { "song" => "Harry Hood", "tease" => "Meatstick", "artist" => nil } ] }

      it "uses the bare title as the note" do
        service.call
        expect(service.proposed_rows.first[3]).to eq("Meatstick")
      end
    end

    context "when the sheet already has the tease for that track" do
      let(:sheet_rows) do
        [ { "URL" => "https://phish.in/2025-12-31/harry-hood", "Notes" => "Norwegian Wood by The Beatles" } ]
      end

      it "does not propose it again" do
        service.call
        expect(service.proposed_rows).to be_empty
      end
    end

    context "when the sheet note omits the artist suffix" do
      let(:sheet_rows) do
        [ { "URL" => "https://phish.in/2025-12-31/harry-hood", "Notes" => "Norwegian Wood" } ]
      end

      it "treats the tease as already covered" do
        service.call
        expect(service.proposed_rows).to be_empty
      end
    end

    context "when the song is not in the show" do
      let(:llm_teases) { [ { "song" => "Divided Sky", "tease" => "Norwegian Wood", "artist" => "The Beatles" } ] }

      it "records it as unmatched instead of proposing a row" do
        service.call

        expect(service.proposed_rows).to be_empty
        expect(service.unmatched.first).to include(song: "Divided Sky", tease: "Norwegian Wood")
      end

      it "does not fall back to an unrelated track in the show" do
        service.call
        expect(service.proposed_rows.map(&:first)).not_to include("https://phish.in/2025-12-31/#{yem.slug}")
      end
    end
  end

  describe "soundcheck teases" do
    let(:setlist_notes) { "The soundcheck's jam included Come Together teases from Trey." }
    let(:llm_teases) do
      [ { "song" => "Soundcheck Jam", "tease" => "Come Together", "artist" => "The Beatles" } ]
    end

    it "ignores them entirely rather than reporting them as unmatched" do
      service.call

      expect(service.proposed_rows).to be_empty
      expect(service.unmatched).to be_empty
    end
  end

  describe "unmatched rows on the Unmatched tab" do
    let(:llm_teases) do
      [ { "song" => "Divided Sky", "tease" => "Norwegian Wood", "artist" => "The Beatles" } ]
    end

    it "appends them to the Unmatched tab when applying" do
      described_class.call(date: "2025-12-31", apply: true)

      expect(GoogleSpreadsheetAppender).to have_received(:call).with(
        "sheet-id",
        described_class::UNMATCHED_RANGE,
        [ [ "2025-12-31", "Divided Sky", "Norwegian Wood by The Beatles", "no phish.in track",
            described_class::DEV_NOTE ] ]
      )
    end

    it "does not write them during a dry run" do
      service.call
      expect(GoogleSpreadsheetAppender).not_to have_received(:call)
    end

    it "falls back to printing the rows when the tab is missing" do
      allow(GoogleSpreadsheetAppender).to receive(:call)
        .and_raise(Google::Apis::ClientError.new("Unable to parse range: UNMATCHED TEASES!A:A"))

      expect { described_class.call(date: "2025-12-31", apply: true) }
        .to output(/no 'UNMATCHED TEASES' tab found/).to_stdout
    end
  end

  describe "artist resolution" do
    context "when Phish.net knows the song" do
      let(:pnet_songs) { [ { "song" => "Sneakin' Sally Thru the Alley", "artist" => "Lee Dorsey" } ] }
      let(:llm_teases) do
        [ { "song" => "Harry Hood", "tease" => "Sneakin' Sally Thru the Alley", "artist" => "Robert Palmer" } ]
      end

      it "prefers the Phish.net artist over the model's guess" do
        service.call

        expect(service.proposed_rows.first[3]).to eq("Sneakin' Sally Thru the Alley by Lee Dorsey")
        expect(service.unverified_artists).to be_empty
      end
    end

    context "when Phish.net lists the song as a Phish original" do
      let(:pnet_songs) { [ { "song" => "Norwegian Wood", "artist" => "Phish" } ] }

      it "omits the artist suffix" do
        service.call
        expect(service.proposed_rows.first[3]).to eq("Norwegian Wood")
      end
    end

    context "when Phish.net does not know the song" do
      it "falls back to the model artist and flags it for review" do
        service.call

        expect(service.proposed_rows.first[3]).to eq("Norwegian Wood by The Beatles")
        expect(service.unverified_artists).to contain_exactly("Norwegian Wood by The Beatles")
      end
    end
  end

  describe "sheet rows absent from Phish.net notes" do
    let(:sheet_rows) do
      [
        { "URL" => "https://phish.in/2025-12-31/you-enjoy-myself", "Notes" => "Kashmir by Led Zeppelin" },
        { "URL" => "https://phish.in/2025-12-31/harry-hood", "Notes" => "Norwegian Wood by The Beatles" }
      ]
    end

    it "reports a sheet tease the notes never mention" do
      service.call

      expect(service.unconfirmed).to contain_exactly(
        a_string_including("you-enjoy-myself").and(a_string_including("Kashmir"))
      )
    end

    it "does not report a sheet tease the notes confirm" do
      service.call
      expect(service.unconfirmed.join).not_to include("Norwegian Wood")
    end

    it "only considers shows that were actually scanned" do
      other = create(:show, date: "2024-07-04")
      create(:track, show: other, title: "Tweezer", position: 1)
      allow(GoogleSpreadsheetFetcher).to receive(:call).and_return(
        sheet_rows + [ { "URL" => "https://phish.in/2024-07-04/tweezer", "Notes" => "Manteca" } ]
      )

      service.call

      expect(service.unconfirmed.join).not_to include("2024-07-04")
    end
  end

  describe "sheet URLs" do
    it "writes production URLs regardless of the local host config" do
      allow(Rails.configuration).to receive(:production_base_url).and_return("https://phish.in")
      service.call

      expect(service.proposed_rows.first.first).to start_with("https://phish.in/2025-12-31/")
    end
  end

  describe "response parsing" do
    it "reads the text block when the model emits a leading thinking block" do
      stub_claude(llm_teases, leading_blocks: [ { "type" => "thinking", "thinking" => "hmm", "signature" => "x" } ])

      service.call

      expect(service.proposed_rows.first[3]).to eq("Norwegian Wood by The Beatles")
    end
  end

  describe "LLM prefilter" do
    let(:setlist_notes) { "The band wore ice cream outfits for the encore." }

    it "does not call the LLM when the notes never mention teasing" do
      service.call

      expect(Typhoeus).not_to have_received(:post)
      expect(service.proposed_rows).to be_empty
    end
  end

  describe "applying to the sheet" do
    it "does not append during a dry run" do
      service.call
      expect(GoogleSpreadsheetAppender).not_to have_received(:call)
    end

    it "appends the proposed rows when apply is true" do
      described_class.call(date: "2025-12-31", apply: true)

      expect(GoogleSpreadsheetAppender).to have_received(:call).with(
        "sheet-id",
        described_class::APPEND_RANGE,
        [ [ hood_url, "", "", "Norwegian Wood by The Beatles", "", described_class::DEV_NOTE ] ]
      )
    end

    it "does not append when there is nothing to add" do
      allow(GoogleSpreadsheetFetcher).to receive(:call).and_return(
        [ { "URL" => "https://phish.in/2025-12-31/harry-hood", "Notes" => "Norwegian Wood by The Beatles" } ]
      )

      described_class.call(date: "2025-12-31", apply: true)

      expect(GoogleSpreadsheetAppender).not_to have_received(:call)
    end
  end

  describe "option validation" do
    it "requires a date scope" do
      expect { described_class.call }.to raise_error(ArgumentError, /DATE/)
    end
  end
end
