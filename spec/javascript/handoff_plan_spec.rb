require "rails_helper"

RSpec.describe "handoffPlan" do # rubocop:disable RSpec/DescribeClass
  def plan(args)
    extractor = Rails.root.join("spec/javascript/support/extract_handoff_plan.js")
    source = Rails.root.join("app/javascript/components/player/handoffPlan.js")
    out = `cd #{Rails.root} && node #{extractor} #{source.to_s.shellescape} #{args.to_json.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a plan, got: #{out}"
  end

  it "starts the buffer a lead ahead of both the clock and the playhead" do
    result = plan(now: 10, position: 30, end: nil, duration: 600)
    expect(result.values_at("at", "offset")).to eq([ 10.1, 30.1 ])
  end

  it "plays to the end of the buffer when the excerpt has no end" do
    expect(plan(now: 0, position: 0, end: nil, duration: 600)["length"]).to be_within(0.001).of(599.9)
  end

  it "stops at the excerpt end" do
    expect(plan(now: 0, position: 100, end: 200, duration: 600)["length"]).to be_within(0.001).of(99.9)
  end

  it "stops at the buffer end when the excerpt end overshoots it" do
    expect(plan(now: 0, position: 100, end: 900, duration: 600)["length"]).to be_within(0.001).of(499.9)
  end

  it "never returns a negative length" do
    expect(plan(now: 0, position: 250, end: 200, duration: 600)["length"]).to eq(0)
  end

  it "carries the fade duration" do
    expect(plan(now: 0, position: 0, end: nil, duration: 600)["fade"]).to eq(0.05)
  end
end
