require "rails_helper"

RSpec.describe ShowImporter::Matcher do
  subject(:result) { described_class.call(date:, filenames:) }

  let(:date) { "2024-07-19" }
  let(:filenames) { [ "I 01 Buried Alive.mp3", "II 01 Suzy Greenberg.mp3" ] }
  let!(:venue) { create(:venue, name: "Deer Creek", city: "Noblesville") }
  let!(:tour) { create(:tour, starts_on: "2024-07-01", ends_on: "2024-07-31") }
  let!(:buried) { create(:song, title: "Buried Alive") }
  let!(:suzy) { create(:song, title: "Suzy Greenberg") }
  let!(:hood) { create(:song, title: "Harry Hood") }
  let(:response) { instance_double(Typhoeus::Response, body: response_body) }
  let(:response_body) do
    {
      data: [
        { artistid: 1, position: 1, song: "Buried Alive", set: "1",
          venue: "Deer Creek", city: "Noblesville" },
        { artistid: 1, position: 2, song: "Suzy Greenberg", set: "2",
          venue: "Deer Creek", city: "Noblesville" },
        { artistid: 1, position: 3, song: "Harry Hood", set: "e",
          venue: "Deer Creek", city: "Noblesville" }
      ]
    }.to_json
  end

  before { allow(Typhoeus).to receive(:get).and_return(response) }

  it "matches venue and tour" do
    expect(result.venue).to eq(venue)
    expect(result.tour).to eq(tour)
  end

  it "exposes the show_info it fetched" do
    expect(result.show_info).to be_a(ShowImporter::ShowInfo)
    expect(result.show_info.venue_name).to eq("Deer Creek")
  end

  it "builds track hashes with filename and song matches" do
    expect(result.tracks.size).to eq(3)

    first = result.tracks.find { |t| t[:position] == 1 }
    expect(first[:title]).to eq("Buried Alive")
    expect(first[:filename]).to eq("I 01 Buried Alive.mp3")
    expect(first[:song_id]).to eq(buried.id)

    second = result.tracks.find { |t| t[:position] == 2 }
    expect(second[:filename]).to eq("II 01 Suzy Greenberg.mp3")
    expect(second[:song_id]).to eq(suzy.id)

    unmatched = result.tracks.find { |t| t[:position] == 3 }
    expect(unmatched[:filename]).to be_nil
    expect(unmatched[:song_id]).to eq(hood.id)
    expect(unmatched[:set]).to eq("E")
  end

  it "returns nil venue when nothing matches" do
    venue.update!(city: "Elsewhere")
    expect(result.venue).to be_nil
  end

  it "returns nil tour when nothing matches" do
    tour.update!(starts_on: "2020-01-01", ends_on: "2020-02-01")
    expect(result.tour).to be_nil
  end

  it "matches a venue by a former name" do
    venue.update!(name: "Some Other Name")
    create(:venue_rename, venue:, name: "Deer Creek", renamed_on: "2020-01-01")
    expect(result.venue).to eq(venue)
  end

  context "when phish.net data lacks a set for a position" do
    let(:response_body) do
      {
        data: [
          { artistid: 1, position: 1, song: "Buried Alive", set: nil,
            venue: "Deer Creek", city: "Noblesville" }
        ]
      }.to_json
    end

    it "infers the set from the filename prefix" do
      expect(result.tracks.first[:set]).to eq("1")
    end

    context "with a second-set filename prefix" do
      let(:filenames) { [ "II 01 Buried Alive.mp3" ] }

      it "infers the set from the filename prefix" do
        expect(result.tracks.first[:set]).to eq("2")
      end
    end
  end

  context "when no song matches the phish.net title" do
    let(:response_body) do
      {
        data: [
          { artistid: 1, position: 1, song: "Some New Debut", set: "1",
            venue: "Deer Creek", city: "Noblesville" }
        ]
      }.to_json
    end
    let(:filenames) { [] }

    it "keeps the phish.net title with no song or filename" do
      track = result.tracks.first
      expect(track[:title]).to eq("Some New Debut")
      expect(track[:song_id]).to be_nil
      expect(track[:filename]).to be_nil
    end
  end

  context "when the date is not found on phish.net" do
    let(:response_body) { { data: [] }.to_json }

    it "propagates NotFoundError" do
      expect { result }.to raise_error(ShowImporter::ShowInfo::NotFoundError)
    end
  end
end
