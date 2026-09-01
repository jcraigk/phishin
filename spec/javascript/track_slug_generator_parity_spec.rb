require "rails_helper"

RSpec.describe TrackSlugGenerator do
  let(:panel) { Rails.root.join("app/javascript/components/admin/BoundaryPanel.jsx") }

  let(:titles) do
    [
      "Hold Your Head Up",
      "Big Black Furry Creature From Mars",
      "The Man Who Stepped Into Yesterday",
      "McGrupp and the Watchful Hosemasters",
      "She Caught the Katy and Left Me a Mule to Ride",
      "Mike's Song",
      "Tweezer > Ghost",
      "Down with Disease",
      "You Enjoy Myself",
      "Punch You in the Eye"
    ]
  end

  def ruby_slug(title)
    base = title.downcase.delete("'").gsub(/[^a-z0-9]/, " ").strip.gsub(/\s+/, "-")
    TrackSlugGenerator.allocate.send(:abbreviate_long_slug, base)
  end

  def js_slugs(panel, titles)
    extractor = Rails.root.join("spec/javascript/support/extract_base_slug.js")
    out = `cd #{Rails.root} && node #{extractor} #{panel.to_s.shellescape} #{titles.to_json.shellescape} 2>&1`
    JSON.parse(out)
  rescue JSON::ParserError
    raise "node did not return JSON, got: #{out}"
  end

  it "computes the same slug as TrackSlugGenerator for every title" do
    expect(js_slugs(panel, titles)).to eq(titles.map { ruby_slug(it) })
  end
end
