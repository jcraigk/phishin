require "rails_helper"

RSpec.describe "pullLabelsLeft" do # rubocop:disable RSpec/DescribeClass
  def pull(positions, spacing, limits)
    extractor = Rails.root.join("spec/javascript/support/extract_pull_labels_left.js")
    source = Rails.root.join("app/javascript/components/helpers/timelineLabels.js")
    args = { positions:, spacing:, limits: }.to_json
    out = `cd #{Rails.root} && node #{extractor} #{source.to_s.shellescape} #{args.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return label positions, got: #{out}"
  end

  it "leaves labels within their limits where they are" do
    expect(pull([ 10, 50 ], 20, [ 100, 100 ])).to eq([ 10, 50 ])
  end

  it "pulls a label back to its limit" do
    expect(pull([ 10, 90 ], 20, [ 100, 70 ])).to eq([ 10, 70 ])
  end

  it "pulls earlier labels along to keep their spacing" do
    expect(pull([ 50, 70, 90 ], 20, [ 100, 100, 60 ])).to eq([ 20, 40, 60 ])
  end
end
