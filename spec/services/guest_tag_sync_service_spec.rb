require "rails_helper"

RSpec.describe GuestTagSyncService do
  subject(:service) { described_class.new(date: "1995-10-31", dry_run: false) }

  let(:show) { create(:show, date: "1995-10-31") }
  let!(:tag) { create(:tag, name: "Guest") }
  let!(:track) { create(:track, show:, title: "Harry Hood", position: 1) }
  let(:footnote) { "Dave Grippo on alto saxophone" }
  let(:song) { "Harry Hood" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("PNET_API_KEY").and_return("key")
    body = { "data" => [ { "song" => song, "footnote" => footnote, "artistid" => 1 } ] }.to_json
    allow(Typhoeus).to receive(:get).and_return(instance_double(Typhoeus::Response, success?: true, body:))
  end

  it "creates a Guest tag from an instrument footnote" do
    expect { service.call }.to change(TrackTag, :count).by(1)

    expect(TrackTag.last).to have_attributes(track:, tag:, notes: "Dave Grippo on alto saxophone")
  end

  it "does not create tags during a dry run" do
    expect { described_class.call(date: "1995-10-31") }.not_to change(TrackTag, :count)
  end

  it "is idempotent" do
    service.call
    expect { described_class.new(date: "1995-10-31", dry_run: false).call }.not_to change(TrackTag, :count)
  end

  describe "band members are not guests" do
    [
      "Fish on trombone",
      "Trey on drums",
      "Page on organ",
      "Mike on accordian"
    ].each do |note|
      context "with #{note.inspect}" do
        let(:footnote) { note }

        it "creates no tag" do
          expect { service.call }.not_to change(TrackTag, :count)
        end
      end
    end
  end

  describe "non-guest footnotes" do
    [
      "Phish debut",
      "Unfinished",
      "Mike on accordian for first known time",
      "Contained a Manteca tease"
    ].each do |note|
      context "with #{note.inspect}" do
        let(:footnote) { note }

        it "creates no tag" do
          expect { service.call }.not_to change(TrackTag, :count)
        end
      end
    end
  end

  context "when a footnote mixes a debut and a guest" do
    let(:footnote) { "First known Phish performance; Jeff on vocals." }

    it "tags only the guest clause" do
      service.call

      expect(TrackTag.last.notes).to eq("Jeff on vocals")
    end
  end

  context "when a footnote names several guests in one clause" do
    let(:footnote) { "Dave Grippo on alto saxophone, Don Glasgo on trombone" }

    it "keeps the clause intact" do
      service.call

      expect(TrackTag.last.notes).to eq("Dave Grippo on alto saxophone, Don Glasgo on trombone")
    end
  end

  describe "clauses that mix a guest with a band member" do
    {
      "Billy Strings on guitar and Page on keytar" => "Billy Strings on guitar",
      "Tony Markellis on bass and Mike on a second guitar" => "Tony Markellis on bass",
      "Ella on vocals, Fish on drums" => "Ella on vocals"
    }.each do |note, expected|
      context "with #{note.inspect}" do
        let(:footnote) { note }

        it "tags only the guest portion" do
          service.call
          expect(TrackTag.last.notes).to eq(expected)
        end
      end
    end
  end

  describe "bare band-member mentions that are not instrument credits" do
    {
      "Steven Drebber on vocals, unknown trumpet player (possibly Fish)" =>
        "Steven Drebber on vocals, unknown trumpet player (possibly Fish)",
      "Carl Gerhard on trumpet, introduced by Trey" =>
        "Carl Gerhard on trumpet, introduced by Trey"
    }.each do |note, expected|
      context "with #{note.inspect}" do
        let(:footnote) { note }

        it "does not truncate the sentence" do
          service.call
          expect(TrackTag.last.notes).to eq(expected)
        end
      end
    end
  end

  describe "clauses where a band member is the object" do
    [
      "Kenwood Dennard replaced Fish on drums",
      "Kenwood Dennard replaced Fish on drums midsong"
    ].each do |note|
      context "with #{note.inspect}" do
        let(:footnote) { note }

        it "keeps the clause intact" do
          service.call
          expect(TrackTag.last.notes).to eq(note)
        end
      end
    end
  end

  describe "band-only clauses that are not clause-initial" do
    [
      "With Trey on Marimba Lumina and Mike on keys",
      "With Page on theremin",
      "Began with Trey on acoustic guitar"
    ].each do |note|
      context "with #{note.inspect}" do
        let(:footnote) { note }

        it "creates no tag" do
          expect { service.call }.not_to change(TrackTag, :count)
        end
      end
    end
  end

  describe "titles phish.in abbreviates" do
    let(:song) { "Hold Your Head Up" }
    let(:footnote) { "John Popper on harmonica" }

    it "matches the abbreviated local title" do
      create(:track, show:, title: "Suspicious Minds > HYHU", position: 40)

      service.call

      expect(TrackTag.last.track.title).to eq("Suspicious Minds > HYHU")
    end
  end

  context "when two setlist entries map to one combined track" do
    let(:show) { create(:show, date: "1996-10-29") }
    let(:song) { "Suspicious Minds" }
    let(:service) { described_class.new(date: "1996-10-29", dry_run: false) }

    before do
      body = {
        "data" => [
          { "song" => "Suspicious Minds", "footnote" => "Karl Perazzo on percussion", "artistid" => 1 },
          { "song" => "Hold Your Head Up", "footnote" => "Karl Perazzo on percussion", "artistid" => 1 }
        ]
      }.to_json
      allow(Typhoeus).to receive(:get).and_return(instance_double(Typhoeus::Response, success?: true, body:))
      create(:track, show:, title: "Suspicious Minds > HYHU", position: 30)
    end


    it "creates only one tag" do
      expect { service.call }.to change(TrackTag, :count).by(1)
    end
  end

  context "when the song has no matching track" do
    let(:song) { "Divided Sky" }

    it "reports it instead of tagging" do
      service.call

      expect(TrackTag.count).to eq(0)
      expect(service.unmatched.first).to include("Divided Sky")
    end
  end

  context "when the footnote has HTML entities" do
    let(:footnote) { "Bela Fleck &amp; Dude of Life on vocals" }

    it "unescapes them" do
      service.call

      expect(TrackTag.last.notes).to eq("Bela Fleck & Dude of Life on vocals")
    end
  end

  it "requires a scope option" do
    expect { described_class.call }.to raise_error(ArgumentError, /YEAR/)
  end
end
