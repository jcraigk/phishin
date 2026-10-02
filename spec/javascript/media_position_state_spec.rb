require "rails_helper"

RSpec.describe "mediaPositionState" do # rubocop:disable RSpec/DescribeClass
  def state(args)
    extractor = Rails.root.join("spec/javascript/support/extract_media_position_state.js")
    source = Rails.root.join("app/javascript/components/player/mediaPositionState.js")
    out = `cd #{Rails.root} && node #{extractor} #{source.to_s.shellescape} #{args.to_json.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a state, got: #{out}"
  end

  it "reports the track duration in seconds" do
    expect(state(durationMs: 600_000, currentTime: 30)["duration"]).to eq(600)
  end

  it "reports the playhead as the position" do
    expect(state(durationMs: 600_000, currentTime: 30)["position"]).to eq(30)
  end

  it "plays at normal rate" do
    expect(state(durationMs: 600_000, currentTime: 30)["playbackRate"]).to eq(1)
  end

  it "clamps a playhead past the end to the duration" do
    expect(state(durationMs: 600_000, currentTime: 601)["position"]).to eq(600)
  end

  it "clamps a negative playhead to zero" do
    expect(state(durationMs: 600_000, currentTime: -1)["position"]).to eq(0)
  end

  it "returns nothing without a duration" do
    expect(state(durationMs: 0, currentTime: 0)).to be_nil
  end
end
