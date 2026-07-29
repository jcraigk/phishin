require "rails_helper"

RSpec.describe Id3AlbumArtChecker do
  subject(:result) { described_class.call(track) }

  let(:show) { create(:show, date: "1995-10-31") }
  let(:track) { create(:track, show:) }

  context "when the mp3 has no attached audio" do
    it "reports the track as unreadable" do
      expect(result).to eq(:unreadable)
    end
  end

  context "when the mp3 has no embedded album art" do
    before { attach_placeholder_audio }

    it "reports the album art as missing" do
      expect(result).to eq(:missing)
    end
  end

  context "when the mp3 has embedded album art" do
    before do
      attach_placeholder_audio
      attach_album_cover
      Id3TagService.call(track)
      track.reload
    end

    it "reports the album art as present" do
      expect(result).to eq(:present)
    end
  end

  def attach_placeholder_audio
    track.mp3_audio.attach(
      io: File.open(Rails.root.join("public/placeholders/audio.mp3")),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )
  end

  def attach_album_cover
    show.album_cover.attach(
      io: File.open(Rails.root.join("public/placeholders/cover-art-medium.jpg")),
      filename: "cover-art-medium.jpg",
      content_type: "image/jpeg"
    )
  end
end
