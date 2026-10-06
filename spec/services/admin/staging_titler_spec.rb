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
      { title: "Buried Alive", set: "1", song_ids: [ buried.id ] },
      { title: "Mike's Song", set: "2", song_ids: [ mikes.id ] }
    ])
  end

  it "matches on filename when the counts differ" do
    result = described_class.call(show:, sources: sources("I 01 Buried Alive.flac", "d1t02.flac", "d1t03.flac"))
    expect(result.first).to eq({ title: "Buried Alive", set: "1", song_ids: [ buried.id ] })
  end

  it "falls back to the filename when nothing matches" do
    result = described_class.call(show:, sources: sources("ph2024_d1t01.flac", "x.flac", "y.flac"))
    expect(result.first).to eq({ title: "ph2024_d1t01", set: "1", song_ids: [] })
  end

  context "with taper notes naming files the setlist cannot place" do
    let(:notes) { "SET I\n01) Tuning\n02) Buried Alive\n\nSET II\n03) Mike's Song\n04) Encore Break" }
    let(:names) { %w[ph2024t01.flac ph2024t02.flac ph2024t03.flac ph2024t04.flac] }

    before do
      allow(Admin::TaperNotesAiTracklist).to receive(:call).and_return(
        "ph2024t01.flac" => "Tuning", "ph2024t02.flac" => "Buried Alive",
        "ph2024t03.flac" => "mike's song", "ph2024t04.flac" => "Encore Break"
      )
    end

    it "labels each file from the notes, taking set and song from the setlist" do
      result = described_class.call(show:, sources: sources(*names), notes:)
      expect(result).to eq([
        { title: "Tuning", set: "1", song_ids: [] },
        { title: "Buried Alive", set: "1", song_ids: [ buried.id ] },
        { title: "Mike's Song", set: "2", song_ids: [ mikes.id ] },
        { title: "Encore Break", set: "2", song_ids: [] }
      ])
    end

    it "matches a notes title to a catalog song when the setlist lacks it" do
      banter = create(:song, title: "Banter")
      allow(Admin::TaperNotesAiTracklist).to receive(:call).and_return("ph2024t01.flac" => "banter")
      result = described_class.call(show:, sources: sources(*names), notes:)
      expect(result.first).to eq({ title: "Banter", set: "1", song_ids: [ banter.id ] })
    end
  end

  it "falls back to filenames when Phish.net has no setlist" do
    allow(Typhoeus).to receive(:get).and_return(instance_double(Typhoeus::Response, body: { data: [] }.to_json))
    result = described_class.call(show:, sources: sources("a.flac"))
    expect(result).to eq([ { title: "a", set: "1", song_ids: [] } ])
  end
end
