require "rails_helper"

RSpec.describe Admin::TaperNotesTracklist do
  let(:notes) do
    <<~NOTES
      PHiSH
      04.13.1993
      Memorial Hall

      Source: Set 1: AKG 451 > DAT

      Disc 1
      01. Suzie Greenberg
      02. Foam
      05. Colonel Forbin's Ascent >
      08. Fly Famous Mockingbird,

      Disc 2
      1) Rift
      t02 - Weekapaug Groove
    NOTES
  end

  it "maps disc and track numbers to cleaned titles" do
    mapping = described_class.call(notes)
    expect(mapping["d1t01"]).to eq("Suzie Greenberg")
    expect(mapping["d1t05"]).to eq("Colonel Forbin's Ascent")
    expect(mapping["d1t08"]).to eq("Fly Famous Mockingbird")
    expect(mapping["d2t01"]).to eq("Rift")
    expect(mapping["d2t02"]).to eq("Weekapaug Groove")
  end

  it "ignores numbered lines before any disc header" do
    expect(described_class.call(notes).values).not_to include(a_string_matching(/1993/))
  end

  it "reads explicit dNtNN lines without a header" do
    mapping = described_class.call("d1t03 - Sparkle\nd2t10. Cavern")
    expect(mapping).to eq({ "d1t03" => "Sparkle", "d2t10" => "Cavern" })
  end

  it "returns an empty mapping for prose" do
    expect(described_class.call("A lovely soundboard recording.")).to eq({})
  end

  describe ".key_for" do
    it "extracts the disc and track from a filename" do
      expect(described_class.key_for("ph1993-04-13d1t01.flac")).to eq("d1t01")
      expect(described_class.key_for("ph93_d2_t07.shn")).to eq("d2t07")
      expect(described_class.key_for("01 Llama.mp3")).to be_nil
    end
  end
end
