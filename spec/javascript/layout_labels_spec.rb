require "rails_helper"

RSpec.describe "layoutLabels" do # rubocop:disable RSpec/DescribeClass
  def layout(centers, sizes)
    extractor = Rails.root.join("spec/javascript/support/extract_layout_labels.js")
    source = Rails.root.join("app/javascript/components/helpers/timelineLabels.js")
    args = { centers:, sizes: }.to_json
    out = `cd #{Rails.root} && node #{extractor} #{source.to_s.shellescape} #{args.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return label tops, got: #{out}"
  end

  it "centers labels that have room on their segments" do
    expect(layout([ 50, 150 ], [ 20, 20 ])).to eq([ 40, 140 ])
  end

  it "spreads colliding labels evenly around their segments" do
    expect(layout([ 100, 102 ], [ 20, 20 ])).to eq([ 81, 101 ])
  end

  it "never places a label before the start of the bar" do
    expect(layout([ 2, 4 ], [ 20, 20 ])).to eq([ 0, 20 ])
  end

  it "pushes earlier labels aside when a later collision cascades into them" do
    expect(layout([ 10, 30, 32 ], [ 20, 20, 20 ])).to eq([ 0, 20, 40 ])
  end

  it "packs labels of different sizes without overlap" do
    expect(layout([ 100, 100 ], [ 40, 20 ])).to eq([ 65, 105 ])
  end
end
