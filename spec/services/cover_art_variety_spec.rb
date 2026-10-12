require "rails_helper"

RSpec.describe CoverArtVariety do
  let(:show) { create(:show, date: "2025-08-10") }

  def histogram_at(degrees)
    Array.new(CoverArtPalette::BINS, 0.0).tap { it[degrees / CoverArtPalette::BIN_DEGREES] = 1.0 }
  end

  def past_run(date, degrees: 225, colorfulness: 0.6, prompt: "a pigeon")
    past = create(:show, date:, cover_art_prompt: prompt)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("img"), filename: "art.jpg", content_type: "image/jpeg")
    blob.update!(metadata: blob.metadata.merge("palette" => { "histogram" => histogram_at(degrees), "colorfulness" => colorfulness }))
    past.cover_art.attach(blob)
    past
  end

  def gap(a, b)
    ((a - b + 180) % 360 - 180).abs
  end

  describe "#hue" do
    it "steers away from the colour of the last few covers" do
      past_run("2025-08-01", degrees: 225)
      past_run("2025-07-25", degrees: 220)
      past_run("2025-07-20", degrees: 230)
      hues = 20.times.map { |seed| described_class.new(show, random: Random.new(seed)).hue }
      expect(hues.map { gap(described_class::HUES.fetch(it), 225) }.min).to be >= described_class::NEIGHBORHOOD_DEGREES
    end

    it "lets a near-grey cover's faint tint be reused" do
      past_run("2025-08-01", degrees: 225, colorfulness: 0.0)
      hues = 50.times.map { |seed| described_class.new(show, random: Random.new(seed)).hue }
      expect(hues.map { gap(described_class::HUES.fetch(it), 225) }.min).to be < described_class::NEIGHBORHOOD_DEGREES
    end

    it "ignores covers from the show's own run" do
      venue = create(:venue)
      own_run = create(:show, date: "2025-08-09", venue:, cover_art_prompt: "own run")
      show.update!(venue:)
      past_run("2025-08-01", degrees: 0)
      expect(described_class.new(show).recent_prompts).not_to include(own_run.cover_art_prompt)
    end

    it "skips covers whose image can't be read" do
      broken = past_run("2025-08-01")
      broken.cover_art.blob.update!(metadata: {})
      allow(CoverArtPalette).to receive(:call).and_raise(ActiveStorage::FileNotFoundError)
      expect(described_class::HUES).to have_key(described_class.new(show).hue)
    end
  end

  describe "#styles" do
    it "drops styles named in recent prompts" do
      past_run("2025-08-01", prompt: "poster art of colorado mountains, brown hue")
      past_run("2025-07-25", prompt: "A rattlesnake in the style of Ink-Drawing with a Blue hue.")
      styles = described_class.new(show).styles(described_class::STYLES.size - 2)
      expect(styles).not_to include("Poster-Art", "Ink-Drawing")
    end

    it "returns distinct styles" do
      styles = described_class.new(show).styles(4)
      expect(styles.uniq.size).to eq(4)
    end
  end

  describe "#recent_prompts" do
    it "lists the most recent runs' prompts, newest first" do
      past_run("2025-07-01", prompt: "older")
      past_run("2025-08-01", prompt: "newer")
      expect(described_class.new(show).recent_prompts).to eq(%w[newer older])
    end
  end
end
