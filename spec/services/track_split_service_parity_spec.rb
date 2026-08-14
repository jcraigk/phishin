require "rails_helper"

# The split review page auditions each side of the cut by asking
# scripts/lead_scan_server.py for a fadeless trim, which it renders with
# trim_filters() from scripts/audio_edge_analysis.py. Production cuts the real
# audio with TrackSplitService. If the two chains drift, the audition stops
# being an honest sample of what gets written, and there is no way to notice by
# listening. This pins them together.
RSpec.describe TrackSplitService do
  let(:script) { Rails.root.join("scripts/audio_edge_analysis.py") }

  # start, end - always fadeless: the two halves come from one continuous
  # recording, so the cut is butt joined on both the preview and the apply path.
  let(:cases) { [ [ 0.0, 236.1 ], [ 20.0, 25.0 ], [ 407.7, 815.4 ] ] }

  # Ask the real Python module for its chains rather than restating them here,
  # so editing the script cannot leave this spec asserting a stale copy.
  def python_filters(specs)
    body = <<~PY
      import importlib.util, json, sys
      spec = importlib.util.spec_from_file_location("aea", #{script.to_s.inspect})
      m = importlib.util.module_from_spec(spec)
      sys.modules["aea"] = m
      spec.loader.exec_module(m)
      print(json.dumps([m.trim_filters(c[0], c[1], 0, 0) for c in json.loads(sys.argv[1])]))
    PY
    file = Tempfile.new([ "parity", ".py" ])
    # Reuse the script's own inline dependency metadata so uv resolves the
    # same environment it runs the scan in.
    file.write(script.read.lines[1..12].join + body)
    file.close
    out, err, status = Open3.capture3("uv", "run", file.path, specs.to_json)
    raise "python failed: #{err}" unless status.success?
    JSON.parse(out)
  ensure
    file&.unlink
  end

  it "builds the same filter chain the preview renders with" do
    expected = python_filters(cases)

    actual = cases.map { |start_s, end_s| described_class.filters(start_s:, end_s:) }

    expect(actual).to eq(expected)
  end
end
