require "rails_helper"

RSpec.describe TrackTagSyncService do
  let(:show) { create(:show, date: "2023-01-01") }
  let(:track) { create(:track, show:) }
  let(:url) { "https://phish.in/#{show.date}/#{track.slug}" }
  let(:data) do
    [
      {
        "URL" => url,
        "Starts At" => "1:30",
        "Ends At" => "2:00",
        "Notes" => notes,
        "Transcript" => nil
      }
    ]
  end

  before do
    create(:tag, name: "Tease")
    allow($stdout).to receive(:write)
  end

  describe "#call" do
    context "when notes contain characters altered by sanitization" do
      let(:notes) { "Rockin’ Robin by Leon René" }

      it "creates a track tag with sanitized notes" do
        expect { described_class.call("Tease", data) }
          .to change(TrackTag, :count).by(1)
        expect(TrackTag.last.notes).to eq("Rockin' Robin by Leon René")
      end

      it "does not create a duplicate on subsequent runs" do
        described_class.call("Tease", data)
        expect { described_class.call("Tease", data) }
          .not_to change(TrackTag, :count)
      end
    end

    context "when notes are unchanged by sanitization" do
      let(:notes) { "Sweet Emotion by Aerosmith" }

      it "does not create a duplicate on subsequent runs" do
        described_class.call("Tease", data)
        expect { described_class.call("Tease", data) }
          .not_to change(TrackTag, :count)
      end
    end
  end
end
