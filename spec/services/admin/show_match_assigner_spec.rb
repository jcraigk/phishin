require "rails_helper"

RSpec.describe Admin::ShowMatchAssigner do
  let(:venue) { create(:venue, name: "Boardwalk Hall", city: "Atlantic City") }
  let!(:parent) { create(:show, date: "2026-10-03", venue:, cover_art_prompt: "Beach grass") }
  let(:show) { create(:show, date: "2026-10-04", venue: nil, tour: nil, published: false) }
  let(:setlist) { [ { artistid: 1, position: 1, song: "Carini", set: "E", venue: "Boardwalk Hall", city: "Atlantic City" } ] }

  before do
    allow(Typhoeus).to receive(:get).and_return(
      instance_double(Typhoeus::Response, code: 200, body: { data: setlist }.to_json)
    )
  end

  it "assigns the venue from Phish.net" do
    described_class.call(show)
    expect(show.reload.venue).to eq(venue)
  end

  it "links the show to its run's cover art once the venue is assigned" do
    described_class.call(show)
    expect(show.reload.cover_art_parent_show_id).to eq(parent.id)
  end

  it "copies the run's prompt once the venue is assigned" do
    described_class.call(show)
    expect(show.reload.cover_art_prompt).to eq("Beach grass")
  end
end
