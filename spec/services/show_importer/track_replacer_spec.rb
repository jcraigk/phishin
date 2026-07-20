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
end
