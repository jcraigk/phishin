require "rails_helper"

RSpec.describe "tagApiRequests" do # rubocop:disable RSpec/DescribeClass
  def headers_for(*urls)
    harness = Rails.root.join("spec/javascript/support/run_tag_api_requests.js")
    source = Rails.root.join("app/javascript/components/helpers/tagApiRequests.js")
    out = `cd #{Rails.root} && node #{harness} #{source.to_s.shellescape} #{urls.to_json.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a result, got: #{out}"
  end

  it "tags relative and absolute same-origin api calls" do
    result = headers_for("/api/v2/years", "https://phish.in/api/v2/shows/1997-11-22")

    expect(result.values).to eq(%w[web web])
  end

  it "leaves audio and third-party requests untagged" do
    result = headers_for("/blob/track.mp3", "https://example.com/api/v2/years")

    expect(result.values).to eq([ nil, nil ])
  end
end
