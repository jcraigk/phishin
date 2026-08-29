# spec/jobs/admin/ingest_staging_job_spec.rb
require "rails_helper"

RSpec.describe Admin::IngestStagingJob do
  let(:show) { create(:show, date: "2024-07-19", published: false, audio_status: "missing", taper_notes: nil) }
  let(:admin_job) { create(:admin_job, kind: "ingest", show:) }
  let(:dir) { Admin::StagingDir.new(show) }
  let(:fixtures) { Rails.root.join("tmp/spec/ingest") }

  # Two short flacs of different lengths, and a zip holding both plus notes.
  before do
    FileUtils.mkdir_p(fixtures)
    { "d1t01.flac" => 4, "d1t02.flac" => 6 }.each do |name, secs|
      path = fixtures.join(name)
      next if File.exist?(path)
      system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
             "sine=frequency=440:duration=#{secs}", "-c:a", "flac", path.to_s, exception: true)
    end
    File.write(fixtures.join("notes.txt"), "Taper: someone")
    zip = fixtures.join("show.zip")
    FileUtils.rm_f(zip)
    system("bsdtar", "-a", "-cf", zip.to_s, "-C", fixtures.to_s, "d1t01.flac", "d1t02.flac", "notes.txt", exception: true)
    allow(Typhoeus).to receive(:get).and_return(
      instance_double(Typhoeus::Response, code: 200, body: { data: [] }.to_json)
    )
    dir.remove!
  end

  def upload(name, content_type)
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(fixtures.join(name)), filename: name, content_type:
    ).signed_id
  end

  describe "from an uploaded zip" do
    it "lays the sources on one timeline and creates a track per file" do
      described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ], nil)

      expect(admin_job.reload.status).to eq("done")
      sources = show.staged_sources.order(:position)
      expect(sources.map(&:filename)).to eq([ "d1t01.flac", "d1t02.flac" ])
      expect(sources.map { it.offset_s.to_f }).to eq([ 0.0, 4.0 ])
      expect(sources.map { it.duration_s.to_f }).to eq([ 4.0, 6.0 ])

      tracks = show.staged_tracks.order(:position)
      expect(tracks.map { [ it.start_s.to_f, it.end_s.to_f ] }).to eq([ [ 0.0, 4.0 ], [ 4.0, 10.0 ] ])
      expect(tracks.map(&:title)).to eq([ "d1t01", "d1t02" ])
    end

    it "builds the timeline and a proxy per lossless source" do
      described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ], nil)
      expect(Admin::AudioProbe.duration_s(dir.timeline)).to be_within(0.1).of(10.0)
      show.staged_sources.each do |source|
        expect(File.exist?(dir.proxy_path(source))).to be(true)
        expect(mp3_frame_sync?(File.binread(dir.proxy_path(source)))).to be(true)
      end
    end

    it "prefills taper notes from a text file" do
      described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ], nil)
      expect(show.reload.taper_notes).to eq("Taper: someone")
    end

    it "leaves taper notes an admin already wrote alone" do
      show.update!(taper_notes: "Typed by admin")
      described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ], nil)
      expect(show.reload.taper_notes).to eq("Typed by admin")
    end

    it "purges the uploaded blobs once unpacked" do
      signed = upload("show.zip", "application/zip")
      described_class.new.perform(show.id, admin_job.id, [ signed ], nil)
      expect(ActiveStorage::Blob.find_signed(signed)).to be_nil
    end
  end

  describe "from loose files" do
    it "accepts audio files uploaded directly" do
      ids = [ upload("d1t02.flac", "audio/flac"), upload("d1t01.flac", "audio/flac") ]
      described_class.new.perform(show.id, admin_job.id, ids, nil)
      expect(show.staged_sources.order(:position).map(&:filename)).to eq([ "d1t01.flac", "d1t02.flac" ])
    end

    it "keeps an uploaded filename with a path component inside the incoming directory" do
      signed = ActiveStorage::Blob.create_and_upload!(
        io: File.open(fixtures.join("d1t01.flac")), filename: "nested/../escape.flac", content_type: "audio/flac"
      ).signed_id
      described_class.new.perform(show.id, admin_job.id, [ signed ], nil)
      source = show.staged_sources.sole
      expect(source.filename).to eq("escape.flac")
      expect(File.exist?(dir.source_path(source))).to be(true)
    end

    it "ignores a symlink planted among the archive's audio" do
      zip = fixtures.join("show_with_symlink.zip")
      unless File.exist?(zip)
        Dir.mktmpdir do |scratch|
          FileUtils.cp(fixtures.join("d1t02.flac"), File.join(scratch, "d1t02.flac"))
          File.symlink(fixtures.join("d1t01.flac"), File.join(scratch, "sneaky.flac"))
          system("bsdtar", "-a", "-cf", zip.to_s, "-C", scratch, "d1t02.flac", "sneaky.flac", exception: true)
        end
      end
      described_class.new.perform(show.id, admin_job.id, [ upload("show_with_symlink.zip", "application/zip") ], nil)
      expect(show.staged_sources.pluck(:filename)).to eq([ "d1t02.flac" ])
    end
  end

  describe "from an archive.org item" do
    it "downloads the item, records its url, and uses its description as notes" do
      item = instance_double(Admin::ArchiveItem, description: "From the item", details_url: "https://archive.org/details/x")
      allow(Admin::ArchiveItem).to receive(:new).with("x").and_return(item)
      allow(item).to receive(:download_to) do |incoming|
        %w[d1t01.flac d1t02.flac].map { FileUtils.cp(fixtures.join(it), incoming); File.join(incoming, it) }
      end

      described_class.new.perform(show.id, admin_job.id, [], "x")

      expect(show.reload.staging_source_url).to eq("https://archive.org/details/x")
      expect(show.taper_notes).to eq("From the item")
      expect(show.staged_sources.count).to eq(2)
    end
  end

  it "fails when the show already has tracks" do
    create(:track, show:, position: 1)
    expect { described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ], nil) }
      .to raise_error(/already has tracks/)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "fails when nothing in the upload is audio" do
    expect { described_class.new.perform(show.id, admin_job.id, [ upload("notes.txt", "text/plain") ], nil) }
      .to raise_error(Admin::IngestStagingJob::NoAudioError)
  end

  it "fails when an uploaded archive unpacks to nothing" do
    empty_zip = fixtures.join("empty.zip")
    unless File.exist?(empty_zip)
      Dir.mktmpdir { |scratch| system("bsdtar", "-a", "-cf", empty_zip.to_s, "-C", scratch, ".", exception: true) }
    end
    expect { described_class.new.perform(show.id, admin_job.id, [ upload("empty.zip", "application/zip") ], nil) }
      .to raise_error(Admin::IngestStagingJob::Error, /unpacked nothing/)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "replaces a previous staging of the same show" do
    described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ], nil)
    second = create(:admin_job, kind: "ingest", show:)
    described_class.new.perform(show.id, second.id, [ upload("d1t01.flac", "audio/flac") ], nil)
    expect(show.staged_sources.count).to eq(1)
    expect(show.staged_tracks.count).to eq(1)
  end
end
