require "rails_helper"

RSpec.describe ShowImporter::Orchestrator do
  subject(:orchestrator) { described_class.new(date) }

  let(:date) { "1995-10-31" }
  let(:import_path) { Dir.mktmpdir }
  let(:placeholder_audio) { Rails.root.join("public/placeholders/audio.mp3") }
  let(:venue) { create(:venue, name: "Rosemont Horizon", city: "Rosemont") }
  let(:show_info) do
    instance_double(
      ShowImporter::ShowInfo,
      songs: {
        1 => "Bold As Love",
        2 => "Say It To Me S.A.N.T.O.S.",
        3 => "Some New Debut"
      },
      venue_name: venue.name,
      venue_city: venue.city
    )
  end

  before do
    create(:tour, starts_on: "1995-01-01", ends_on: "1995-12-31")
    create(:song, title: "Bold as Love")
    create(:song, title: "Say It to Me S.A.N.T.O.S.")

    allow(App).to receive(:content_import_path).and_return(import_path)
    allow(ShowImporter::ShowInfo).to receive(:new).with(date).and_return(show_info)
    allow($stdout).to receive(:write)
    allow($stderr).to receive(:write)

    FileUtils.mkdir_p("#{import_path}/#{date}")
    FileUtils.cp(placeholder_audio, "#{import_path}/#{date}/I 01 Bold_as_Love.mp3")
  end

  after do
    FileUtils.remove_entry(import_path)
  end

  it "matches a filename-linked song despite phish.net casing and uses the local title" do
    track = orchestrator.get_track(1)
    expect(track.title).to eq("Bold as Love")
    expect(track.songs.map(&:title)).to eq([ "Bold as Love" ])
    expect(track.filename).to eq("I 01 Bold_as_Love.mp3")
  end

  it "uses the local song title and association when no filename matches" do
    track = orchestrator.get_track(2)
    expect(track.title).to eq("Say It to Me S.A.N.T.O.S.")
    expect(track.songs.map(&:title)).to eq([ "Say It to Me S.A.N.T.O.S." ])
  end

  it "keeps the phish.net title verbatim when no song matches" do
    track = orchestrator.get_track(3)
    expect(track.title).to eq("Some New Debut")
    expect(track.songs).to be_empty
  end
end
