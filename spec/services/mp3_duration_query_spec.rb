require "rails_helper"

RSpec.describe Mp3DurationQuery do
  subject(:service) { described_class }

  let(:track) { create(:track) }
  let(:attachment) { track.mp3_audio }

  context "when attachment is missing" do
    let(:track) { create(:track, attachments: false) }

    it "raises Errno::ENOENT" do
      expect { service.call(attachment) }.to raise_error(Errno::ENOENT)
    end
  end

  context "when attachment is a non-MP3 file" do
    before do
      track.mp3_audio.attach \
        io: StringIO.new("This is not an MP3"),
        filename: "invalid.txt",
        content_type: "text/plain"
    end

    it "raises Mp3InfoEOFError" do
      expect { service.call(attachment) }.to raise_error(Mp3InfoEOFError)
    end
  end

  context "when attachment is a valid MP3 file" do
    it "returns the duration in milliseconds" do
      expected_duration = 2011 # Adjust based on the actual duration of audio_file.mp3
      expect(service.call(attachment)).to eq(expected_duration)
    end
  end
end
