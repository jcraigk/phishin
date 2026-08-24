require "rails_helper"

RSpec.describe TeaseTrackMatcher do
  let(:show) { create(:show, date: "1993-05-03") }

  it "prefers an exact title over a track that merely contains the label" do
    reprise = create(:track, show:, title: "Tweezer Reprise", position: 1)
    tweezer = create(:track, show:, title: "Tweezer", position: 2)

    expect(described_class.call(show, [ "Tweezer" ])).to eq([ tweezer ])
    expect(described_class.call(show, [ "Tweezer Reprise" ])).to eq([ reprise ])
  end

  it "prefers a sandwich segment over a track that merely contains the label" do
    create(:track, show:, title: "Tweezer Reprise", position: 1)
    sandwich = create(:track, show:, title: "Tweezer > Manteca > Tweezer", position: 2)

    expect(described_class.call(show, [ "Tweezer" ])).to eq([ sandwich ])
  end

  it "returns every same-title track in setlist order" do
    second = create(:track, show:, title: "Tweezer", position: 9)
    first = create(:track, show:, title: "Tweezer", position: 3)

    expect(described_class.call(show, [ "Tweezer" ])).to eq([ first, second ])
  end

  it "falls back to a substring match when nothing matches exactly" do
    hood = create(:track, show:, title: "Harry Hood", position: 1)

    expect(described_class.call(show, [ "Hood" ])).to eq([ hood ])
  end

  it "tries labels in order, stopping at the first that matches" do
    hood = create(:track, show:, title: "Harry Hood", position: 1)

    expect(described_class.call(show, [ "Harry Hood", "Hood" ])).to eq([ hood ])
    expect(described_class.call(show, [ "Nonexistent", "Hood" ])).to eq([ hood ])
  end

  it "returns an empty list for a blank or unknown label" do
    create(:track, show:, title: "Harry Hood", position: 1)

    expect(described_class.call(show, [ "" ])).to eq([])
    expect(described_class.call(show, [ "Sand" ])).to eq([])
  end
end
