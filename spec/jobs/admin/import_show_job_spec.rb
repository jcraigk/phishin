require "rails_helper"

RSpec.describe Admin::ImportShowJob do
  subject(:run_job) { described_class.new.perform(show.id, admin_job.id) }

  let(:show) do
    create(:show, date: "2024-07-19", published: false, venue: nil, tour: nil, audio_status: "missing")
  end
  let(:admin_job) { create(:admin_job, kind: "import", show:) }
  let!(:venue) { create(:venue, name: "Deer Creek", city: "Noblesville") }
  let!(:tour) { create(:tour, starts_on: "2024-07-01", ends_on: "2024-07-31") }
  let!(:buried) { create(:song, title: "Buried Alive") }
  let!(:mikes) { create(:song, title: "Mike's Song") }
  let(:response) { instance_double(Typhoeus::Response, body: response_body) }
  let(:setlist) do
    [
      { artistid: 1, position: 1, song: "Buried Alive", set: "1",
        venue: "Deer Creek", city: "Noblesville" },
      { artistid: 1, position: 2, song: "Mike's Song", set: "1",
        venue: "Deer Creek", city: "Noblesville" }
    ]
  end
  let(:response_body) { { data: setlist }.to_json }

  def stage_mp3(filename)
    path = Rails.root.join("tmp/spec/import_show_job.mp3")
    FileUtils.mkdir_p(path.dirname)
    unless File.exist?(path)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=8", "-b:a", "128k", path.to_s,
        exception: true
      )
    end
    show.staged_audio.attach(io: File.open(path), filename:, content_type: "audio/mpeg")
  end

  before do
    allow(Typhoeus).to receive(:get).and_return(response)
    stage_mp3("I 01 Buried Alive.mp3")
    # The ">" here is the trap: ActiveStorage sanitizes it out of Filename#to_s,
    # so the job must correlate blobs by their original filename column.
    stage_mp3("I 02 Mike's Song > I Am Hydrogen.mp3")
  end

  it "creates tracks with positions, titles, sets, and songs" do
    run_job

    tracks = show.reload.tracks.order(:position)
    expect(tracks.map(&:position)).to eq([ 1, 2 ])
    expect(tracks.map(&:title)).to eq([ "Buried Alive", "Mike's Song" ])
    expect(tracks.map(&:set)).to eq([ "1", "1" ])
    expect(tracks.map { |t| t.songs.to_a }).to eq([ [ buried ], [ mikes ] ])
  end

  it "attaches and processes audio for every matched track" do
    run_job

    show.reload.tracks.each do |track|
      expect(track.mp3_audio).to be_attached
      expect(track.duration).to be > 0
      expect(track.audio_status).to eq("complete")
      expect(track.png_waveform).to be_attached
    end
  end

  it "attaches audio matched through the unsanitized filename" do
    run_job

    track = show.reload.tracks.find_by(position: 2)
    expect(track.mp3_audio).to be_attached
  end

  it "assigns the matched venue and tour" do
    run_job

    show.reload
    expect(show.venue).to eq(venue)
    expect(show.tour).to eq(tour)
  end

  it "sets the show duration and audio status from its tracks" do
    run_job

    show.reload
    expect(show.audio_status).to eq("complete")
    expect(show.duration).to be > 0
  end

  it "clears staged audio without destroying any blob" do
    blob_ids = show.staged_audio_attachments.map(&:blob_id)

    run_job

    expect(show.reload.staged_audio_attachments).to be_empty
    expect(ActiveStorage::Blob.where(id: blob_ids).count).to eq(blob_ids.size)
  end

  # A staged blob is the source of a track's audio, so purging one would delete
  # a file still in use. process_mp3_audio replaces mp3_audio, and replacement
  # purges the blob it replaces, so the track must never hold the staged blob.
  it "never enqueues a purge for a staged blob" do
    staged_ids = show.staged_audio_attachments.map(&:blob_id)
    purged_ids = []
    allow(ActiveStorage::PurgeJob).to receive(:perform_later) { |blob| purged_ids << blob.id }

    run_job

    expect(purged_ids).not_to include(*staged_ids)
  end

  it "leaves the staged audio downloadable after the import" do
    blobs = show.staged_audio_attachments.map(&:blob)

    run_job

    blobs.each { |blob| expect(blob.reload.download.bytesize).to be > 0 }
  end

  it "reports progress and finishes done" do
    run_job

    admin_job.reload
    expect(admin_job.status).to eq("done")
    expect(admin_job.progress).to eq(100)
    expect(admin_job.message).to eq("Import complete")
  end

  it "advances progress as each track is imported" do
    progress = []
    allow(AdminJob).to receive(:find).with(admin_job.id).and_return(admin_job)
    allow(admin_job).to receive(:update!).and_wrap_original do |method, attrs|
      progress << attrs[:progress] if attrs.key?(:progress)
      method.call(attrs)
    end

    run_job

    expect(progress).to eq([ 45, 90, 100 ])
  end

  context "when the venue does not match" do
    before { venue.update!(city: "Elsewhere") }

    it "records the unmatched venue in the job payload" do
      run_job

      expect(admin_job.reload.payload["unmatched_venue"])
        .to eq({ "name" => "Deer Creek", "city" => "Noblesville" })
    end

    it "leaves the show venue unset" do
      run_job
      expect(show.reload.venue).to be_nil
    end

    it "still completes the import" do
      run_job
      expect(admin_job.reload.status).to eq("done")
      expect(show.reload.tracks.count).to eq(2)
    end
  end

  context "when no tour covers the date" do
    before { tour.update!(starts_on: "2020-01-01", ends_on: "2020-12-31") }

    it "records the unmatched tour in the job payload" do
      run_job
      expect(admin_job.reload.payload["unmatched_tour"]).to be(true)
    end

    it "leaves the show tour unset" do
      run_job
      expect(show.reload.tour).to be_nil
    end
  end

  context "when a setlist song is not in the database" do
    let(:setlist) do
      [ { artistid: 1, position: 1, song: "Some New Debut", set: "2",
          venue: "Deer Creek", city: "Noblesville" } ]
    end

    it "creates the track with no songs and no audio" do
      run_job

      track = show.reload.tracks.sole
      expect(track.title).to eq("Some New Debut")
      expect(track.songs).to be_empty
      expect(track.audio_status).to eq("missing")
    end
  end

  context "when Phish.net has no data for the date" do
    let(:setlist) { [] }

    it "fails the job with a readable message" do
      expect { run_job }.to raise_error(ShowImporter::ShowInfo::NotFoundError)

      admin_job.reload
      expect(admin_job.status).to eq("failed")
      expect(admin_job.message).to include("not found on Phish.net")
    end

    it "creates no tracks" do
      expect { run_job }.to raise_error(ShowImporter::ShowInfo::NotFoundError)
      expect(show.reload.tracks).to be_empty
    end
  end

  context "when the show already has tracks" do
    before { create(:track, show:, position: 1, songs: [ buried ]) }

    it "fails without importing" do
      expect { run_job }.to raise_error(/already has tracks/)

      expect(admin_job.reload.status).to eq("failed")
      expect(admin_job.message).to include("already has tracks")
      expect(show.reload.tracks.count).to eq(1)
    end
  end
end
