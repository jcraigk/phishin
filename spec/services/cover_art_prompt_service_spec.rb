require "rails_helper"

RSpec.describe CoverArtPromptService do
  let(:venue) { create(:venue, name: "Orion Amphitheater", city: "Huntsville", state: "AL") }
  let(:tour) { create(:tour, name: "Fall Tour 2026") }
  let(:show) { create(:show, date: "2026-10-11", venue:, tour:, taper_notes: "Taped from row 12") }
  let(:llm_prompts) do
    [
      "A Saturn V rocket rising through hurricane clouds, screen print with teal and cream",
      "A mini drum kit on a wet stage at dusk, watercolor",
      "A possum under a magnolia, linocut",
      "Rain on an empty amphitheater lawn, photograph"
    ]
  end
  let(:pnet_notes) { "<p>Free, Fuego, and Twenty Years Later featured Trey on mini drum kit.</p>" }
  let(:sent_prompts) { [] }

  before do
    piper = create(:song, title: "Piper")
    traffic = create(:song, title: "Slave to the Traffic Light")
    create(:track, show:, position: 1, set: "1", title: "Piper", songs: [ piper ])
    last = create(:track, show:, position: 2, set: "E", title: "Slave to the Traffic Light", songs: [ traffic ])
    create(:track_tag, track: last, tag: create(:tag, name: "Banter"), notes: "Trey thanks the crowd",
                       transcript: "TREY: Thanks for waiting out the hurricane.")
    allow(Typhoeus).to receive(:get).and_return(
      instance_double(Typhoeus::Response, success?: true, body: { data: [ { setlist_notes: pnet_notes } ] }.to_json)
    )
    allow(OpenRouter).to receive(:chat) do |prompt:, **|
      sent_prompts << prompt
      OpenRouter::ChatResult.new(text: { prompts: llm_prompts }.to_json, input_tokens: 0, output_tokens: 0, cost: 0)
    end
  end

  describe "a dry run" do
    let(:result) { described_class.call(show, dry_run: true) }

    it "returns one finished prompt per candidate, each ending with the album cover rules" do
      expect(result[:prompts].size).to eq(described_class::CANDIDATES)
      expect(result[:prompts]).to all(end_with(described_class::SUFFIX))
    end

    it "offers the first candidate as the prompt" do
      expect(result[:prompt]).to eq(result[:prompts].first)
      expect(result[:prompt]).to start_with("A Saturn V rocket")
    end

    it "leaves the show's saved prompt alone" do
      show.update!(cover_art_prompt: "keep me")
      result
      expect(show.reload.cover_art_prompt).to eq("keep me")
    end

    it "reports the hue and the style assigned to each candidate" do
      expect(CoverArtVariety::HUES).to have_key(result[:hue])
      expect(result[:styles].uniq.size).to eq(described_class::CANDIDATES)
    end
  end

  describe "the brief sent to the model" do
    let(:brief) do
      described_class.call(show, dry_run: true)
      sent_prompts.first
    end

    it "describes the place, date and tour" do
      expect(brief).to include("Orion Amphitheater", "Huntsville, AL", "Sunday, October 11, 2026", "autumn", "Fall Tour 2026")
    end

    it "lists the setlist by set" do
      expect(brief).to include("Set 1: Piper", "Encore: Slave to the Traffic Light")
    end

    it "includes phish.net setlist notes without markup" do
      expect(brief).to include("Trey on mini drum kit")
      expect(brief).not_to include("<p>")
    end

    it "includes tag notes and banter transcripts" do
      expect(brief).to include("Trey thanks the crowd", "waiting out the hurricane")
    end

    it "includes the taper notes" do
      expect(brief).to include("Taped from row 12")
    end

    it "assigns the chosen hue and a different style to each candidate" do
      result = described_class.call(show, dry_run: true)
      sent = sent_prompts.last
      expect(sent).to include(result[:hue])
      result[:styles].each { expect(sent).to include(it.tr("-", " ").downcase) }
    end

    it "shows the recent runs' prompts so their subjects aren't repeated" do
      allow_any_instance_of(CoverArtVariety).to receive(:recent_prompts).and_return([ "a confused firefly" ]) # rubocop:disable RSpec/AnyInstance
      expect(brief).to include("a confused firefly")
    end

    it "still builds a brief when phish.net is unreachable" do
      allow(Typhoeus).to receive(:get).and_return(instance_double(Typhoeus::Response, success?: false))
      expect(brief).to include("Orion Amphitheater")
    end
  end

  it "saves the first candidate on a run's first show" do
    described_class.call(show)
    expect(show.reload.cover_art_prompt).to start_with("A Saturn V rocket")
  end

  it "raises when the model returns no prompts" do
    allow(OpenRouter).to receive(:chat).and_return(
      OpenRouter::ChatResult.new(text: { prompts: [] }.to_json, input_tokens: 0, output_tokens: 0, cost: 0)
    )
    expect { described_class.call(show, dry_run: true) }.to raise_error(described_class::Error)
  end
end
