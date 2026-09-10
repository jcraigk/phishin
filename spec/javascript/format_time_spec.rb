require "rails_helper"

RSpec.describe "formatTime" do # rubocop:disable RSpec/DescribeClass
  def format_time(value)
    extractor = Rails.root.join("spec/javascript/support/extract_format_time.js")
    source = Rails.root.join("app/javascript/components/helpers/utils.js")
    out = `cd #{Rails.root} && node #{extractor} #{source.to_s.shellescape} #{value.to_json.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return a string, got: #{out}"
  end

  it "formats minutes and zero-padded seconds" do
    expect(format_time(59.9)).to eq("0:59")
  end

  it "formats an hour-long value as minutes" do
    expect(format_time(3725)).to eq("62:05")
  end

  it "never shows a negative value when the position runs past the duration" do
    expect(format_time(-0.05)).to eq("0:00")
  end

  it "never shows a negative value for a larger overshoot" do
    expect(format_time(-1.2)).to eq("0:00")
  end

  it "shows zero for a value that is not a number" do
    expect(format_time(nil)).to eq("0:00")
  end
end
