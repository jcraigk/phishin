require "rails_helper"

RSpec.describe "formatShortDate" do # rubocop:disable RSpec/DescribeClass
  def format_short_date(value)
    extractor = Rails.root.join("spec/javascript/support/extract_format_short_date.js")
    source = Rails.root.join("app/javascript/components/helpers/utils.js")
    out = `cd #{Rails.root} && node #{extractor} #{source.to_s.shellescape} #{value.to_json.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a string, got: #{out}"
  end

  it "formats a date the way fans write it, without zero padding" do
    expect(format_short_date("1997-11-07")).to eq("11/7/97")
  end

  it "keeps two-digit years for dates after 2000" do
    expect(format_short_date("2024-01-01")).to eq("1/1/24")
  end

  it "returns an empty string for a missing date" do
    expect(format_short_date(nil)).to eq("")
  end
end
