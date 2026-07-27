require "rails_helper"

RSpec.describe ShowImporter::TrackReplacer do
  subject(:service) { described_class.new(date) }

  let(:show) { create(:show) }
  let(:date) { show.date.to_s }
  let(:import_path) { Dir.mktmpdir }
  let(:placeholder_audio) { Rails.root.join("public/placeholders/audio.mp3") }
  let(:track1) { create(:track, show:, title: "Tweezer", position: 1, duration: 999) }
  let(:track2) { create(:track, show:, title: "Harry Hood", position: 2, duration: 999) }

  before do
    allow(App).to receive(:content_import_path).and_return(import_path)
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    allow(Rails.cache).to receive(:clear)
    allow($stdin).to receive(:gets).and_return("Y")
    allow($stdout).to receive(:write)
    allow($stderr).to receive(:write)

    FileUtils.mkdir_p("#{import_path}/#{date}")
    FileUtils.cp(placeholder_audio, "#{import_path}/#{date}/I 01 Tweezer.mp3")
    FileUtils.cp(placeholder_audio, "#{import_path}/#{date}/I 02 Harry_Hood.mp3")

    track1
    track2
  end

  after do
    FileUtils.remove_entry(import_path)
  end

  it "attaches new audio to each matched track" do
    service
    expect(track1.reload.mp3_audio).to be_attached
    expect(track2.reload.mp3_audio).to be_attached
  end

  it "updates each track's duration from the new audio" do
    expect { service }.to change { track1.reload.duration }.from(999)
  end

  it "updates the show duration from the new track durations" do
    service
    expect(show.reload.duration).to eq(track1.reload.duration + track2.reload.duration)
  end

  it "applies ID3 tags to the new audio" do
    service
    expect(Id3TagService).to have_received(:call).twice
  end

  it "regenerates waveform images" do
    service
    expect(WaveformImageService).to have_received(:call).twice
  end

  context "when notes.txt is present in the import folder" do
    before do
      File.write("#{import_path}/#{date}/notes.txt", "Updated taper notes")
    end

    it "updates the show's taper_notes" do
      service
      expect(show.reload.taper_notes).to eq("Updated taper notes")
    end
  end

  context "when notes.txt is absent from the import folder" do
    let(:show) { create(:show, taper_notes: "Original taper notes") }

    it "leaves the show's taper_notes unchanged" do
      service
      expect(show.reload.taper_notes).to eq("Original taper notes")
    end
  end

  context "when a track is currently missing audio" do
    let(:track2) do
      create(:track, show:, title: "Harry Hood", position: 2, duration: 999, audio_status: "missing")
    end

    it "marks the track's audio as complete" do
      service
      expect(track2.reload.audio_status).to eq("complete")
    end

    it "attaches the new audio" do
      service
      expect(track2.reload.mp3_audio).to be_attached
    end

    it "updates the track's duration from the new audio" do
      expect { service }.to change { track2.reload.duration }.from(999)
    end

    it "marks the show's audio as complete" do
      service
      expect(show.reload.audio_status).to eq("complete")
    end
  end

  context "when a file doesn't match any track" do
    before do
      FileUtils.mv(
        "#{import_path}/#{date}/I 02 Harry_Hood.mp3",
        "#{import_path}/#{date}/I 02 Hrry_Hod.mp3"
      )
    end

    it "aborts listing the unmatched track's position and title" do
      expect { service }.to raise_error(SystemExit, /2\. Harry Hood/)
    end

    it "aborts listing the unmatched filename" do
      expect { service }.to raise_error(SystemExit, /I 02 Hrry_Hod\.mp3/)
    end
  end
end
