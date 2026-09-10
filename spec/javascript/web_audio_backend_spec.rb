require "rails_helper"

RSpec.describe "WebAudioBackend" do # rubocop:disable RSpec/DescribeClass
  def scenario(name)
    harness = Rails.root.join("spec/javascript/support/run_player_scenario.js")
    player_dir = Rails.root.join("app/javascript/components/player")
    out = `cd #{Rails.root} && node #{harness} #{player_dir.to_s.shellescape} #{name.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a result, got: #{out}"
  end

  def element_plays(result)
    result["log"].select { |entry| entry.first == "element.play" }
  end

  def source_starts(result)
    result["log"].select { |entry| entry.first == "source.start" }
  end

  describe "an undecoded track" do
    let(:result) { scenario("backend streams an undecoded track") }

    it "starts the element at the requested position" do
      expect(element_plays(result)).to include([ "element.play", "a.mp3", 0 ])
      expect(result["position"]).to eq(15)
    end

    it "clears loading once the element is playing" do
      expect(result["loading"]).to eq([ true, false ])
    end

    it "counts as playing" do
      expect(result["playing"]).to be(true)
    end
  end

  describe "handoff" do
    let(:result) { scenario("backend hands off to the buffer when decoded") }

    it "starts the buffer a lead ahead of the element's position on the context clock" do
      expect(source_starts(result).first).to eq([ "source.start", 2.1, 7.1, 592.9 ])
    end

    it "replaces the streaming record with a buffer record" do
      expect(result["afterHandoff"]["streaming"]).to be(false)
    end

    it "pauses the element after the fade" do
      expect(result["pausedLater"]).to be(true)
    end

    it "schedules the next track once on the buffer path" do
      expect(source_starts(result).length).to eq(2)
    end

    it "ramps the buffer gain in over the fade" do
      expect(result["log"]).to include([ "gain.ramp", 1, 2.15 ])
    end
  end

  it "plays a decoded track from its buffer without the element" do
    result = scenario("backend skips the element for a decoded track")
    expect(result.values_at("playsBefore", "playsAfter")).to eq([ 1, 1 ])
    expect(source_starts(result).last[2]).to eq(100)
    disconnects = result["log"].select { |entry| entry == [ "disconnect" ] }
    expect(disconnects.length).to be >= 2
  end

  it "clears loading after a stall once the buffer hands off" do
    result = scenario("backend clears loading at handoff")
    expect(result["loading"]).to eq([ true, false, true, false ])
  end

  it "leaves no context behind when destroyed before the decode arrives" do
    result = scenario("backend destroy before decode leaves no context")
    expect(result["ctx"]).to be(true)
  end

  it "pauses the element and reports no position when paused mid-stream" do
    result = scenario("backend pause while streaming stops the element")
    expect(result.values_at("paused", "position")).to eq([ true, nil ])
  end

  it "streams the next track when the element ends before the decode arrives" do
    result = scenario("backend advances when the element ends before decode")
    expect(result["advances"]).to eq([ 1 ])
    expect(element_plays(result).last).to eq([ "element.play", "b.mp3", 0 ])
  end

  it "ends a streamed excerpt at its end time" do
    result = scenario("backend ends a streamed excerpt at its end")
    expect(result.values_at("advancesBeforeEnd", "advances")).to eq([ [], [ 1 ] ])
  end

  it "surfaces an element error and stops" do
    result = scenario("backend reports an element error")
    expect(result["errors"]).to eq([ "Failed to stream a.mp3" ])
    expect(result["playing"]).to be(false)
  end
end
