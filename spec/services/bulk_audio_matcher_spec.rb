require "rails_helper"

RSpec.describe BulkAudioMatcher do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:ghost) { create(:song, title: "Ghost") }
  let(:gin) { create(:song, title: "Bathtub Gin") }
  let!(:track1) do
    create(:track, show:, position: 1, title: "Ghost", songs: [ ghost ])
  end
  let!(:track2) do
    create(:track, show:, position: 2, title: "Bathtub Gin", songs: [ gin ],
                   audio_status: "missing")
  end
  let(:source) { Rails.root.join("tmp/spec/audio_20s_880.mp3") }

  before do
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    FileUtils.mkdir_p(source.dirname)
    unless File.exist?(source)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=880:duration=20", "-b:a", "128k", source.to_s, exception: true
      )
    end
    attach_audio(track1)
  end

  def attach_audio(track)
    track.mp3_audio.attach(
      io: File.open(source), filename: "existing.mp3", content_type: "audio/mpeg"
    )
    track.update!(audio_status: "complete")
  end

  def blob(filename)
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(source), filename:, content_type: "audio/mpeg"
    )
  end

  def plan(*filenames)
    described_class.call(show:, blobs: filenames.map { |f| blob(f) })
  end

  describe "matching by leading position number" do
    subject(:result) { plan("01 Ghost.mp3", "02 Bathtub Gin.mp3") }

    it "matches both files" do
      expect(result[:matches].map { |m| m[:track_id] }).to eq([ track1.id, track2.id ])
    end

    it "marks the track that already has audio as a replace" do
      expect(result[:matches].first[:action]).to eq("replace")
    end

    it "marks the track without audio as a fill" do
      expect(result[:matches].second[:action]).to eq("fill")
    end

    it "reports the track position and title alongside the filename" do
      expect(result[:matches].first)
        .to include(filename: "01 Ghost.mp3", position: 1, title: "Ghost")
    end

    it "leaves nothing unmatched" do
      expect(result[:unmatched_filenames]).to be_empty
    end

    it "reports each file's duration in milliseconds" do
      expect(result[:matches].first[:duration]).to be_within(500).of(20_000)
    end

    it "reports a playable blob url for each file" do
      expect(result[:matches].first[:url]).to start_with("/rails/active_storage/blobs/")
    end
  end

  it "orders matches by track position" do
    result = plan("02 Bathtub Gin.mp3", "01 Ghost.mp3")
    expect(result[:matches].map { |m| m[:position] }).to eq([ 1, 2 ])
  end

  it "matches on a set-prefixed position like the importer's filenames" do
    result = plan("II-02_Bathtub Gin.mp3")
    expect(result[:matches].first[:track_id]).to eq(track2.id)
  end

  it "falls back to song title when the filename carries no position" do
    result = plan("Bathtub Gin.mp3")
    expect(result[:matches].first[:track_id]).to eq(track2.id)
  end

  it "lists files that match no track" do
    result = plan("99 Soundcheck Jam.mp3")
    expect(result[:unmatched_filenames]).to eq([ "99 Soundcheck Jam.mp3" ])
  end

  it "never assigns two files to the same track" do
    result = plan("01 Ghost.mp3", "Ghost.mp3")
    expect(result[:matches].map { |m| m[:track_id] }).to eq([ track1.id ])
  end

  it "reports the tracks that still have no audio" do
    result = plan("01 Ghost.mp3")
    expect(result[:tracks_without_audio])
      .to eq([ { track_id: track2.id, position: 2, title: "Bathtub Gin" } ])
  end

  it "carries the signed id of each matched blob" do
    result = plan("01 Ghost.mp3")
    signed_id = result[:matches].first[:signed_id]
    expect(ActiveStorage::Blob.find_signed!(signed_id)).to be_present
  end

  it "reports the unsanitized filename for a segue" do
    result = plan("03 Mike's Song > I Am Hydrogen.mp3")
    expect(result[:unmatched_filenames] + result[:matches].map { |m| m[:filename] })
      .to eq([ "03 Mike's Song > I Am Hydrogen.mp3" ])
  end

  it "changes no track audio" do
    key = track1.mp3_audio.blob.key
    plan("01 Ghost.mp3", "02 Bathtub Gin.mp3")
    expect(track1.reload.mp3_audio.blob.key).to eq(key)
  end

  it "attaches nothing to the track that had no audio" do
    plan("02 Bathtub Gin.mp3")
    expect(track2.reload.mp3_audio.attached?).to be(false)
  end
end
