require "rails_helper"

RSpec.describe TrackTagDedupeService do
  let!(:tag) { create(:tag, name: "Tease") }
  let(:track) { create(:track) }

  before { allow($stdout).to receive(:write) }

  describe "#call" do
    context "with exact duplicate track tags" do
      let!(:original) do
        create(
          :track_tag,
          tag:,
          track:,
          notes: "O Canada by Calixa Lavallée",
          starts_at_second: 90
        )
      end

      before do
        create_list(
          :track_tag,
          2,
          tag:,
          track:,
          notes: "O Canada by Calixa Lavallée",
          starts_at_second: 90
        )
      end

      it "removes all but the oldest record" do
        expect { described_class.call }.to change(TrackTag, :count).from(3).to(1)
        expect(TrackTag.all).to contain_exactly(original)
      end
    end

    context "with records that differ in starts_at_second" do
      let!(:first_tease) do
        create(:track_tag, tag:, track:, notes: "O Canada", starts_at_second: 90)
      end
      let!(:second_tease) do
        create(:track_tag, tag:, track:, notes: "O Canada", starts_at_second: 300)
      end

      it "keeps both records" do
        described_class.call
        expect(TrackTag.all).to contain_exactly(first_tease, second_tease)
      end
    end
  end
end
