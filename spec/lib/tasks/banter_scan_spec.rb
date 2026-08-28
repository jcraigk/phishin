require "rails_helper"
require "rake"

RSpec.describe "banter_scan" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("banter_scan:run")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/banter_scan.rake")
  end

  describe ".alternate_source_note" do
    it "frames the title the way hand-merged shows do and links the item" do
      note = BanterScan.alternate_source_note("Audience Chess Move", "Source: AKG 460\nTaper: X",
                                              item: "phish1995-11-11.110602")
      rule = "=" * "Audience Chess Move FROM ALTERNATE SOURCE:".length
      expect(note).to eq(<<~NOTE.strip)
        #{rule}
        Audience Chess Move FROM ALTERNATE SOURCE:
        #{rule}

        https://archive.org/details/phish1995-11-11.110602

        Source: AKG 460
        Taper: X
      NOTE
    end
  end

  describe ".append_alternate_source_note" do
    let(:show) { create(:show, taper_notes: "Original notes.\n") }

    it "appends the block after the existing notes" do
      BanterScan.append_alternate_source_note(show, "Audience Chess Move", "info", item: "item1")
      expect(show.reload.taper_notes).to start_with("Original notes.\n\n=====")
      expect(show.taper_notes).to include("Audience Chess Move FROM ALTERNATE SOURCE:")
      expect(show.taper_notes).to end_with("info")
    end

    it "does not append the same note twice" do
      BanterScan.append_alternate_source_note(show, "Audience Chess Move", "info", item: "item1")
      expect(BanterScan.append_alternate_source_note(show, "Audience Chess Move", "info", item: "item1")).to be_nil
      expect(show.reload.taper_notes.scan("FROM ALTERNATE SOURCE").size).to eq(1)
    end

    it "adds a second block for a second title" do
      BanterScan.append_alternate_source_note(show, "Audience Chess Move", "info", item: "item1")
      BanterScan.append_alternate_source_note(show, "Banter", "other", item: "item2")
      expect(show.reload.taper_notes.scan("FROM ALTERNATE SOURCE").size).to eq(2)
    end
  end
end
