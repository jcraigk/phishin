require "rails_helper"

RSpec.describe GuestTagAuditService do
  let!(:tag) { create(:tag, name: "Guest") }
  let(:show) { create(:show, date: "1994-06-29") }

  def guest_tag(notes, title: "I Didn't Know")
    track = create(:track, show:, title:, position: rand(1..500))
    TrackTag.create!(track:, tag:, notes:)
  end

  describe "tags naming a real guest" do
    [
      "Gordon Stone on pedal steel guitar",
      "Mimi Fishman on vacuum",
      "Dr. Jack McConnell on vocals and tap shoes",
      "Ninja Mike on vocals, Magoo on guitar",
      "Butch Trucks on drums, Fish on trombone",
      "Trey on fiddle and \"Reverend\" Jeff Mosier on banjo and vocals",
      "John Medeski on keyboards, Billy Martin on Fish's drums",
      "Billy Strings on guitar"
    ].each do |notes|
      it "leaves #{notes.inspect} alone" do
        record = guest_tag(notes)

        described_class.call(dry_run: false)

        expect(record.reload.notes).to eq(notes)
      end
    end
  end

  describe "tags describing only band members" do
    [
      "Fish played his bass drum pedal on his knees, and also used Trey's megaphone",
      "first by Mike, and then by Page solo on the theremin",
      "With full band drum solo and Fish using mallets on bass"
    ].each do |notes|
      it "deletes #{notes.inspect}" do
        record = guest_tag(notes)

        described_class.call(dry_run: false)

        expect(TrackTag.find_by(id: record.id)).to be_nil
      end
    end
  end

  it "reports without changing anything during a dry run" do
    record = guest_tag("With full band drum solo and Fish using mallets on bass")

    report = described_class.call

    expect(report[:flagged].map { |e| e[:id] }).to eq([ record.id ])
    expect(report[:deleted]).to eq(0)
    expect(record.reload).to be_present
  end

  it "counts every Guest tag it scanned" do
    guest_tag("Billy Strings on guitar")
    guest_tag("With full band drum solo and Fish using mallets on bass")

    expect(described_class.call[:scanned]).to eq(2)
  end

  it "ignores tags for other tags" do
    other = create(:tag, name: "Alt Rig")
    track = create(:track, show:, title: "Possum", position: 900)
    record = TrackTag.create!(track:, tag: other, notes: "Fish on marimba")

    described_class.call(dry_run: false)

    expect(record.reload).to be_present
  end

  it "leaves a blank note alone" do
    record = guest_tag("")

    described_class.call(dry_run: false)

    expect(record.reload).to be_present
  end
end
