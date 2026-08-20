require "rails_helper"

# The boundary panel previews the slug a rename will produce, which means
# TrackSlugGenerator's transform now exists twice: once in Ruby and once as
# baseSlug/SLUG_ABBREVIATIONS in BoundaryPanel.jsx. Nothing forces the two to
# agree, and a drifted copy does not fail loudly - it quietly shows an admin a
# slug the server will not write. This drives the panel's own source so editing
# one side without the other fails here rather than in front of an admin.
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

  # Runs the extractor against the panel's own source, so this cannot pass
  # against a transform the panel has stopped using.
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
