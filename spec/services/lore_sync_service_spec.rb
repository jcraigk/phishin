require "rails_helper"

RSpec.describe LoreSyncService do
  let(:show) { create(:show) }
  let(:track) { create(:track, show:) }
  let(:tag) { create(:tag, name: "Alt Rig") }
  let(:service) { described_class.new(date: show.date.to_s) }

  before do
    service.instance_variable_set(:@pbar, double(log: nil))
    service.instance_variable_set(:@track_tagged, 0)
    service.instance_variable_set(:@track_updated, 0)
    service.instance_variable_set(:@show_tagged, 0)
    service.instance_variable_set(:@show_updated, 0)
  end

  describe "#apply_track_tags" do
    it "does not update when existing notes differ only by the stripped trailing period" do
      TrackTag.create!(track:, tag:, notes: "Trey on a mini drum kit.")

      service.send(
        :apply_track_tags,
        show,
        [ { "song_title" => track.title, "notes" => "Trey on a mini drum kit." } ],
        tag,
        "Alt Rig"
      )

      expect(service.instance_variable_get(:@track_updated)).to eq(0)
    end
  end

  describe "#apply_show_tag" do
    it "does not update when existing notes differ only by the stripped trailing period" do
      ShowTag.create!(show:, tag:, notes: "Fish's minivan was given away.")

      service.send(:apply_show_tag, show, "Fish's minivan was given away.", tag, "Lore")

      expect(service.instance_variable_get(:@show_updated)).to eq(0)
    end
  end
end
