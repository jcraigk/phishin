require "rails_helper"

RSpec.describe "staging playbackHost" do # rubocop:disable RSpec/DescribeClass
  def playback_host(tracks, at)
    extractor = Rails.root.join("spec/javascript/support/extract_playback_host.js")
    math = Rails.root.join("app/javascript/components/admin/stagingMath.js")
    args = { tracks:, at: }.to_json
    out = `cd #{Rails.root} && node #{extractor} #{math.to_s.shellescape} #{args.shellescape} 2>&1`
    JSON.parse(out).symbolize_keys
  rescue JSON::ParserError
    raise "node did not return a host, got: #{out}"
  end

  let(:tracks) { [ { start_s: 0, end_s: 100 }, { start_s: 100, end_s: 200 }, { start_s: 260, end_s: 300 } ] }

  it "hosts a moment inside a track with that track" do
    expect(playback_host(tracks, 150)).to eq(index: 1, gap: false)
  end

  it "hands a seam moment to the later track" do
    expect(playback_host(tracks, 100)).to eq(index: 1, gap: false)
  end

  it "hosts a moment in a cut gap with the track that follows it" do
    expect(playback_host(tracks, 230)).to eq(index: 2, gap: true)
  end

  it "hosts a moment before the first track with the first track" do
    expect(playback_host([ { start_s: 10, end_s: 20 } ], 5)).to eq(index: 0, gap: true)
  end

  it "hosts a moment after the last track with the last track" do
    expect(playback_host(tracks, 310)).to eq(index: 2, gap: true)
  end
end
