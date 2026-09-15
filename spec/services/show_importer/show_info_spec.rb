require "rails_helper"

RSpec.describe ShowImporter::ShowInfo do
  subject(:show_info) { described_class.new(date) }

  let(:date) { "2024-07-19" }
  let(:response) { instance_double(Typhoeus::Response, body: response_body) }
  let(:response_body) do
    {
      data: [
        {
          artistid: 1,
          position: 1,
          song: "Buried Alive",
          set: "1",
          venue: "Deer Creek",
          city: "Noblesville"
        },
        {
          artistid: 1,
          position: 2,
          song: "Suzy Greenberg",
          set: "2",
          venue: "Deer Creek",
          city: "Noblesville"
        },
        {
          artistid: 1,
          position: 3,
          song: "Harry Hood",
          set: "e",
          venue: "Deer Creek",
          city: "Noblesville"
        },
        {
          artistid: 5,
          position: 1,
          song: "Some Opener Song",
          set: "1",
          venue: "Deer Creek",
          city: "Noblesville"
        }
      ]
    }.to_json
  end

  before do
    allow(Typhoeus).to receive(:get).and_return(response)
  end

  it "maps positions to song titles for Phish tracks only" do
    expect(show_info.songs).to eq(
      1 => "Buried Alive",
      2 => "Suzy Greenberg",
      3 => "Harry Hood"
    )
  end

  it "maps positions to normalized set identifiers" do
    expect(show_info.sets).to eq(
      1 => "1",
      2 => "2",
      3 => "E"
    )
  end

  context "when the date is not found on Phish.net" do
    let(:response_body) { { data: [] }.to_json }

    it "raises NotFoundError" do
      expect { show_info }.to raise_error(
        described_class::NotFoundError, "Date \"#{date}\" not found on Phish.net"
      )
    end
  end
end
