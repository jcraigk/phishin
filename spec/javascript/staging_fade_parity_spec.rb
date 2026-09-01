require "rails_helper"

RSpec.describe "staging fade parity" do # rubocop:disable RSpec/DescribeClass
  let(:math) { Rails.root.join("app/javascript/components/admin/stagingMath.js") }

  def gain_at(track, seconds)
    extractor = Rails.root.join("spec/javascript/support/extract_gain_at.js")
    out = `cd #{Rails.root} && node #{extractor} #{math.to_s.shellescape} #{track.to_json.shellescape} #{seconds} 2>&1`
    Float(out)
  rescue ArgumentError
    raise "node did not return a number, got: #{out}"
  end

  it "is half way up one second into a two second fade-in" do
    track = { start_s: 0, end_s: 10, fade_in_s: 2, fade_out_s: 0 }
    expect(gain_at(track, 1.0)).to be_within(0.001).of(0.5)
    expect(gain_at(track, 4.0)).to eq(1.0)
  end

  it "is half way down two seconds before the end of a four second fade-out" do
    track = { start_s: 0, end_s: 10, fade_in_s: 0, fade_out_s: 4 }
    expect(gain_at(track, 8.0)).to be_within(0.001).of(0.5)
    expect(gain_at(track, 2.0)).to eq(1.0)
  end

  it "measures from the track's own start, not the timeline's" do
    track = { start_s: 100, end_s: 110, fade_in_s: 2, fade_out_s: 0 }
    expect(gain_at(track, 101.0)).to be_within(0.001).of(0.5)
  end

  it "is silent outside the track" do
    track = { start_s: 10, end_s: 20, fade_in_s: 0, fade_out_s: 0 }
    expect(gain_at(track, 9.9)).to eq(0.0)
    expect(gain_at(track, 20.1)).to eq(0.0)
  end
end
