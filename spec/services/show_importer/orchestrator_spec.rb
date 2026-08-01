require "rails_helper"

RSpec.describe ShowImporter::Orchestrator do
  subject(:orchestrator) { described_class.new(date) }

  let(:date) { "1995-10-31" }
  let(:import_path) { Dir.mktmpdir }
  let(:placeholder_audio) { Rails.root.join("public/placeholders/audio.mp3") }
  let(:venue) { create(:venue, name: "Rosemont Horizon", city: "Rosemont") }
  let(:sets) do
    {
      1 => "1",
      2 => "2",
      3 => "E",
      4 => "E"
    }
  end
  let(:show_info) do
    instance_double(
      ShowImporter::ShowInfo,
      songs: {
        1 => "Bold As Love",
        2 => "Run Like an Antelope",
        3 => "Say It To Me S.A.N.T.O.S.",
        4 => "Some New Debut"
      },
      sets:,
      venue_name: venue.name,
      venue_city: venue.city
    )
  end

  before do
    create(:tour, starts_on: "1995-01-01", ends_on: "1995-12-31")
    create(:song, title: "Bold as Love")
    create(:song, title: "Run Like an Antelope")
    create(:song, title: "Say It to Me S.A.N.T.O.S.")

    allow(App).to receive(:content_import_path).and_return(import_path)
    allow(ShowImporter::ShowInfo).to receive(:new).with(date).and_return(show_info)
    allow($stdout).to receive(:write)
    allow($stderr).to receive(:write)

    FileUtils.mkdir_p("#{import_path}/#{date}")
    FileUtils.cp(placeholder_audio, "#{import_path}/#{date}/01 Bold_as_Love.mp3")
    FileUtils.cp(placeholder_audio, "#{import_path}/#{date}/09 Run_Like_an_Antelope.mp3")
  end

  after do
    FileUtils.remove_entry(import_path)
  end

  it "matches a filename-linked song despite phish.net casing and uses the local title" do
    track = orchestrator.get_track(1)
    expect(track.title).to eq("Bold as Love")
    expect(track.songs.map(&:title)).to eq([ "Bold as Love" ])
    expect(track.filename).to eq("01 Bold_as_Love.mp3")
  end

  it "uses the local song title and association when no filename matches" do
    track = orchestrator.get_track(3)
    expect(track.title).to eq("Say It to Me S.A.N.T.O.S.")
    expect(track.songs.map(&:title)).to eq([ "Say It to Me S.A.N.T.O.S." ])
  end

  it "keeps the phish.net title verbatim when no song matches" do
    track = orchestrator.get_track(4)
    expect(track.title).to eq("Some New Debut")
    expect(track.songs).to be_empty
  end

  it "assigns the set from phish.net data when the filename has no set prefix" do
    expect(orchestrator.get_track(2).set).to eq("2")
  end

  it "assigns the set from phish.net data when no filename matches" do
    expect(orchestrator.get_track(3).set).to eq("E")
  end

  context "when phish.net data lacks a set for a position" do
    let(:sets) { { 1 => nil, 2 => "2", 3 => "E", 4 => "E" } }

    it "falls back to inferring the set from the filename" do
      FileUtils.rm("#{import_path}/#{date}/01 Bold_as_Love.mp3")
      FileUtils.cp(placeholder_audio, "#{import_path}/#{date}/II 01 Bold_as_Love.mp3")
      expect(orchestrator.get_track(1).set).to eq("2")
    end
  end
end
