require "rails_helper"

# The lead-scan preview renders audio with scripts/audio_edge_analysis.py while
# production applies it with AudioEdgeTrimService. If the two ffmpeg filter
# chains drift, a preview stops being an honest sample of what gets written to
# the track, and there is no way to notice by listening. This pins them together.
RSpec.describe AudioEdgeTrimService do
  let(:script) { Rails.root.join("scripts/audio_edge_analysis.py") }

  # start, end, fade_in, fade_out
  let(:cases) do
    [
      [ 6.0, 300.0, 1.0, 6.0 ],   # both edges trimmed
      [ 0.0, 300.0, 1.0, 6.0 ],   # start clamped to 0: no splice, so no fade-in
      [ 6.0, 310.0, 1.0, 0.0 ],   # leading only
      [ 0.0, 300.0, 0.0, 6.0 ],   # trailing only
      [ 6.0, 8.0, 1.0, 6.0 ],     # fade-out longer than the kept span
      [ 6.0, 300.0, 0.0, 0.0 ]    # fades disabled
    ]
  end

  # Ask the real Python module for its chains rather than restating them here,
  # so editing the script cannot leave this spec asserting a stale copy.
  def python_filters(specs)
    body = <<~PY
      import importlib.util, json, sys
      spec = importlib.util.spec_from_file_location("aea", #{script.to_s.inspect})
      m = importlib.util.module_from_spec(spec)
      sys.modules["aea"] = m
      spec.loader.exec_module(m)
      print(json.dumps([m.trim_filters(*c) for c in json.loads(sys.argv[1])]))
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

  it "builds the same filter chain as the scan script" do
    expected = python_filters(cases)

    actual = cases.map do |trim_start, trim_end, fade_in, fade_out|
      described_class.filters(trim_start:, trim_end:, fade_in:, fade_out:)
    end

    expect(actual).to eq(expected)
  end
end
