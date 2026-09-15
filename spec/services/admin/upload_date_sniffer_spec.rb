require "rails_helper"

RSpec.describe Admin::UploadDateSniffer do
  def blob(filename, content: "x", content_type: "application/octet-stream")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename:, content_type:
    )
  end

  it "reads an ISO date from taper notes" do
    blobs = [ blob("notes.txt", content: "Phish\n2026-09-04\nDick's", content_type: "text/plain") ]
    expect(described_class.call(blobs)).to eq(Date.new(2026, 9, 4))
  end

  it "reads a US-style date from taper notes" do
    blobs = [ blob("notes.txt", content: "Phish\n9/4/2026\nDick's", content_type: "text/plain") ]
    expect(described_class.call(blobs)).to eq(Date.new(2026, 9, 4))
  end

  it "reads a month-name date from taper notes" do
    blobs = [ blob("notes.txt", content: "September 06, 2026 (Sunday)", content_type: "text/plain") ]
    expect(described_class.call(blobs)).to eq(Date.new(2026, 9, 6))
  end

  it "prefers the notes over the filenames" do
    blobs = [
      blob("phish2020-01-01-t01.flac"),
      blob("notes.txt", content: "9/4/2026", content_type: "text/plain")
    ]
    expect(described_class.call(blobs)).to eq(Date.new(2026, 9, 4))
  end

  it "falls back to a date embedded in filenames" do
    blobs = [ blob("phish2026-09-05dpa4015-t01.flac"), blob("phish2026-09-05dpa4015-t02.flac") ]
    expect(described_class.call(blobs)).to eq(Date.new(2026, 9, 5))
  end

  it "reads compact filename dates" do
    blobs = [ blob("Phish2026.09.06.Chase.zip") ]
    expect(described_class.call(blobs)).to eq(Date.new(2026, 9, 6))
  end

  it "returns nil when nothing carries a date" do
    blobs = [ blob("set1.flac"), blob("notes.txt", content: "no date here", content_type: "text/plain") ]
    expect(described_class.call(blobs)).to be_nil
  end

  it "ignores impossible dates" do
    blobs = [ blob("notes.txt", content: "2026-02-31", content_type: "text/plain") ]
    expect(described_class.call(blobs)).to be_nil
  end
end
