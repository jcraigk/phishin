require "rails_helper"

RSpec.describe Admin::StagingTitler do
  let(:show) { create(:show, date: "2024-07-19") }
  let!(:buried) { create(:song, title: "Buried Alive") }
  let!(:mikes) { create(:song, title: "Mike's Song") }
  let(:setlist) do
    [
      { artistid: 1, position: 1, song: "Buried Alive", set: "1", venue: "V", city: "C" },
      { artistid: 1, position: 2, song: "Mike's Song", set: "2", venue: "V", city: "C" }
    ]
  end
  let(:response) { instance_double(Typhoeus::Response, body: { data: setlist }.to_json) }

  before { allow(Typhoeus).to receive(:get).and_return(response) }

  def sources(*names)
    names.each_with_index.map { |name, i| build(:staged_source, show:, position: i + 1, filename: name) }
  end

  it "assigns the setlist by position when the counts match" do
    result = described_class.call(show:, sources: sources("d1t01.flac", "d1t02.flac"))
    expect(result).to eq([
      { title: "Buried Alive", set: "1", song_id: buried.id },
      { title: "Mike's Song", set: "2", song_id: mikes.id }
    ])
  end

  it "matches on filename when the counts differ" do
    result = described_class.call(show:, sources: sources("I 01 Buried Alive.flac", "d1t02.flac", "d1t03.flac"))
    expect(result.first).to eq({ title: "Buried Alive", set: "1", song_id: buried.id })
  end

  it "falls back to the filename when nothing matches" do
    result = described_class.call(show:, sources: sources("ph2024_d1t01.flac", "x.flac", "y.flac"))
    expect(result.first).to eq({ title: "ph2024_d1t01", set: "1", song_id: nil })
  end

  it "falls back to filenames when Phish.net has no setlist" do
    allow(Typhoeus).to receive(:get).and_return(instance_double(Typhoeus::Response, body: { data: [] }.to_json))
    result = described_class.call(show:, sources: sources("a.flac"))
    expect(result).to eq([ { title: "a", set: "1", song_id: nil } ])
  end
end
