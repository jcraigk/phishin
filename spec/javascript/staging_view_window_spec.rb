require "rails_helper"

RSpec.describe "staging viewWindow" do # rubocop:disable RSpec/DescribeClass
  def view_window(tracks, index, pad: 30)
    extractor = Rails.root.join("spec/javascript/support/extract_view_window.js")
    math = Rails.root.join("app/javascript/components/admin/stagingMath.js")
    args = { tracks:, index:, pad: }.to_json
    out = `cd #{Rails.root} && node #{extractor} #{math.to_s.shellescape} #{args.shellescape} 2>&1`
    JSON.parse(out).symbolize_keys
  rescue JSON::ParserError
    raise "node did not return a window, got: #{out}"
  end

  def track(start_s, end_s, set: "2", **extra)
    { start_s:, end_s:, set:, **extra }
  end

  it "pads into a same-set neighbor on each side of a seam" do
    tracks = [ track(0, 100), track(100, 200), track(200, 300) ]
    expect(view_window(tracks, 1)).to eq(start: 50, end: 250)
  end

  it "stops at the track edge at a set break with no gap" do
    tracks = [ track(0, 100, set: "1"), track(100, 200), track(200, 300, set: "E") ]
    expect(view_window(tracks, 1)).to eq(start: 100, end: 200)
  end

  it "reaches the next track's start when a deleted track left a gap after a set break" do
    tracks = [ track(0, 100), track(100, 200), track(260, 300, set: "E") ]
    expect(view_window(tracks, 1)).to eq(start: 50, end: 260)
  end

  it "reaches back to the previous track's end when a gap sits before a set break" do
    tracks = [ track(0, 100, set: "1"), track(140, 200), track(200, 300) ]
    expect(view_window(tracks, 1)).to eq(start: 100, end: 230)
  end

  it "keeps the original end in view after the end was trimmed inward" do
    tracks = [ track(0, 100), track(100, 180, original_end_s: 200), track(200, 300, set: "E") ]
    expect(view_window(tracks, 1)[:end]).to eq(200)
  end

  it "keeps the original end in view for the last track of the show" do
    tracks = [ track(0, 100), track(100, 180, original_end_s: 200) ]
    expect(view_window(tracks, 1)[:end]).to eq(200)
  end
end
