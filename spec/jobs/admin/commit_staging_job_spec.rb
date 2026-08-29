require "rails_helper"

RSpec.describe Admin::CommitStagingJob do
  let(:show) { create(:show, date: "2024-07-19", published: false, venue: nil, tour: nil, audio_status: "missing") }
  let(:admin_job) { create(:admin_job, kind: "commit_staging", show:) }
  let(:dir) { Admin::StagingDir.new(show) }
  let!(:venue) { create(:venue, name: "Deer Creek", city: "Noblesville") }
  let!(:tour) { create(:tour, starts_on: "2024-07-01", ends_on: "2024-07-31") }
  let(:song) { create(:song, title: "Ghost") }
  let(:setlist) { [ { artistid: 1, position: 1, song: "Ghost", set: "1", venue: "Deer Creek", city: "Noblesville" } ] }

  # A ten second flac timeline made of one lossless source, plus a separate
  # 4s mp3 source case set up per example.
  before do
    allow(Typhoeus).to receive(:get).and_return(
      instance_double(Typhoeus::Response, body: { data: setlist }.to_json)
    )
    allow(WaveformImageService).to receive(:call)
    dir.reset!
    system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=10",
           "-c:a", "flac", dir.timeline.to_s, exception: true)
  end

  def probe(path) = Admin::AudioProbe.duration_s(path)

  context "with a lossless source split into two tracks" do
    before do
      create(:staged_source, show:, position: 1, filename: "d1t01.flac", format: "flac", offset_s: 0, duration_s: 10)
      create(:staged_track, show:, position: 1, title: "Ghost", set: "1", song:, start_s: 0, end_s: 6, fade_out_s: 1)
      create(:staged_track, show:, position: 2, title: "Banter", set: "1", start_s: 6, end_s: 10)
    end

    it "creates tracks with rendered audio and metadata" do
      described_class.new.perform(show.id, admin_job.id)

      expect(admin_job.reload.status).to eq("done")
      tracks = show.reload.tracks.order(:position)
      expect(tracks.map(&:title)).to eq([ "Ghost", "Banter" ])
      expect(tracks.first.songs).to eq([ song ])
      expect(tracks.map(&:audio_status)).to eq(%w[complete complete])
      expect(tracks.first.duration).to be_within(200).of(6_000)
      expect(tracks.second.duration).to be_within(200).of(4_000)
      expect(tracks.first.mp3_audio.blob.filename.to_s).to eq("Phish 2024-07-19 01 Ghost.mp3")
    end

    it "assigns venue and tour from Phish.net" do
      described_class.new.perform(show.id, admin_job.id)
      expect(show.reload.venue).to eq(venue)
      expect(show.tour).to eq(tour)
    end

    it "removes the staging rows and directory" do
      described_class.new.perform(show.id, admin_job.id)
      expect(show.reload.staged_tracks).to be_empty
      expect(show.staged_sources).to be_empty
      expect(Dir.exist?(dir.root)).to be(false)
    end

    it "appends the source url to the taper notes" do
      show.update!(taper_notes: "Taper: X", staging_source_url: "https://archive.org/details/x")
      described_class.new.perform(show.id, admin_job.id)
      expect(show.reload.taper_notes).to eq("Taper: X\n\nSource: https://archive.org/details/x")
      expect(show.staging_source_url).to be_nil
    end

    it "updates the show audio status and duration" do
      described_class.new.perform(show.id, admin_job.id)
      expect(show.reload.audio_status).to eq("complete")
      expect(show.duration).to be_within(400).of(10_000)
    end
  end

  context "with an untouched mp3 source" do
    let(:mp3) { Rails.root.join("tmp/spec/commit_source.mp3") }

    before do
      allow(Admin::StagingRender).to receive(:call).and_call_original
      system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=4",
             "-b:a", "128k", mp3.to_s, exception: true)
      source = create(:staged_source, show:, position: 1, filename: "a.mp3", format: "mp3", offset_s: 0, duration_s: 4)
      FileUtils.cp(mp3, dir.source_path(source))
      create(:staged_track, show:, position: 1, title: "Ghost", set: "1", song:, start_s: 0, end_s: 4)
    end

    # The whole point of passthrough: an mp3 show imports as it does today, with
    # no encode. The attached bytes are the source bytes (before the ID3 rewrite
    # process_mp3_audio applies), so the audio frames are compared.
    it "copies the file through without re-encoding" do
      described_class.new.perform(show.id, admin_job.id)
      expect(Admin::StagingRender).not_to have_received(:call)
      expect(show.reload.tracks.first.duration).to be_within(100).of(4_000)
    end

    it "renders when a fade is set" do
      show.staged_tracks.first.update!(fade_out_s: 1)
      described_class.new.perform(show.id, admin_job.id)
      expect(Admin::StagingRender).to have_received(:call)
    end
  end

  it "fails when the show is published" do
    show.update!(venue:, tour:, published: true)
    create(:staged_track, show:)
    expect { described_class.new.perform(show.id, admin_job.id) }.to raise_error(/already published/)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "fails when nothing is staged" do
    expect { described_class.new.perform(show.id, admin_job.id) }.to raise_error(/nothing staged/)
  end

  context "with tracks left by an earlier, failed commit" do
    before do
      create(:track, show:, position: 1, title: "Leftover")
      create(:staged_source, show:, position: 1, filename: "d1t01.flac", format: "flac", offset_s: 0, duration_s: 10)
      create(:staged_track, show:, position: 1, title: "Ghost", set: "1", song:, start_s: 0, end_s: 6, fade_out_s: 1)
      create(:staged_track, show:, position: 2, title: "Banter", set: "1", start_s: 6, end_s: 10)
    end

    it "clears the leftover tracks and commits only the staged ones" do
      described_class.new.perform(show.id, admin_job.id)
      expect(admin_job.reload.status).to eq("done")
      tracks = show.reload.tracks.order(:position)
      expect(tracks.map(&:title)).to eq([ "Ghost", "Banter" ])
    end
  end
end
