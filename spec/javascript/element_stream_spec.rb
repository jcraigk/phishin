require "rails_helper"

RSpec.describe "ElementStream" do # rubocop:disable RSpec/DescribeClass
  def scenario(name)
    harness = Rails.root.join("spec/javascript/support/run_player_scenario.js")
    player_dir = Rails.root.join("app/javascript/components/player")
    out = `cd #{Rails.root} && node #{harness} #{player_dir.to_s.shellescape} #{name.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a result, got: #{out}"
  end

  it "wraps the element once with anonymous CORS and starts it muted" do
    result = scenario("stream starts muted and opens on playing")
    expect(result["log"].first).to eq([ "wrap", "anonymous" ])
    expect(result["gainBeforePlaying"]).to eq(0)
  end

  it "applies the requested position once metadata is known" do
    expect(scenario("stream starts muted and opens on playing")["seekApplied"]).to eq(42)
  end

  it "opens the gain and reports playing" do
    result = scenario("stream starts muted and opens on playing")
    expect(result.values_at("gainAfterPlaying", "events")).to eq([ 1, [ "playing" ] ])
  end

  it "seeks in place when the url is unchanged" do
    result = scenario("stream seeks in place for the same url")
    expect(result.values_at("currentTime", "src")).to eq([ 30, "a.mp3" ])
  end

  it "pauses the element only after the fade has run" do
    result = scenario("stream fade out pauses the element after the ramp")
    expect(result.values_at("pausedImmediately", "pausedLater", "active")).to eq([ false, true, false ])
  end

  it "stops reporting element events after pause" do
    expect(scenario("stream ignores events once paused")["events"]).to eq([])
  end
end
