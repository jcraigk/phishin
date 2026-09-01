require "rails_helper"

RSpec.describe Admin::PrepareBulkAudioJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:admin_job) { create(:admin_job, kind: "bulk_audio_prepare", show:) }
  let(:fixtures) { Rails.root.join("tmp/spec/bulk_prepare") }

  before do
    FileUtils.mkdir_p(fixtures)
    { "d1t01.flac" => 3, "d1t02.flac" => 4 }.each do |name, secs|
      path = fixtures.join(name)
      next if File.exist?(path)
      system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
             "sine=frequency=440:duration=#{secs}", "-c:a", "flac", path.to_s, exception: true)
    end
    mp3 = fixtures.join("d2t01.mp3")
    unless File.exist?(mp3)
      system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
             "sine=frequency=440:duration=2", "-b:a", "128k", mp3.to_s, exception: true)
    end
    zip = fixtures.join("show.zip")
    FileUtils.rm_f(zip)
    system("bsdtar", "-a", "-cf", zip.to_s, "-C", fixtures.to_s,
           "d1t01.flac", "d1t02.flac", "d2t01.mp3", exception: true)
  end

  def upload(name, content_type)
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(fixtures.join(name)), filename: name, content_type:
    ).signed_id
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  it "unpacks a zip and turns every file into an mp3 blob" do
    described_class.new.perform(show.id, admin_job.id, [ upload("show.zip", "application/zip") ])

    expect(admin_job.reload.status).to eq("done")
    blobs = admin_job.payload["signed_ids"].map { ActiveStorage::Blob.find_signed!(it) }
    expect(blobs.map { it.filename.to_s }).to eq(%w[d1t01.mp3 d1t02.mp3 d2t01.mp3])
    blobs.each do |blob|
      expect(mp3_frame_sync?(blob.download)).to be(true)
    end
  end

  it "transcodes a loose flac at its full length" do
    described_class.new.perform(show.id, admin_job.id, [ upload("d1t01.flac", "audio/flac") ])
    blob = ActiveStorage::Blob.find_signed!(admin_job.reload.payload["signed_ids"].first)
    Tempfile.create([ "prepared", ".mp3" ]) do |file|
      file.binmode
      file.write(blob.download)
      file.flush
      expect(probe_duration(file.path)).to be_within(0.2).of(3.0)
    end
  end

  it "passes an mp3 through without renaming it" do
    described_class.new.perform(show.id, admin_job.id, [ upload("d2t01.mp3", "audio/mpeg") ])
    blob = ActiveStorage::Blob.find_signed!(admin_job.reload.payload["signed_ids"].first)
    expect(blob.filename.to_s).to eq("d2t01.mp3")
  end

  it "purges the uploaded transport blobs" do
    signed = upload("show.zip", "application/zip")
    described_class.new.perform(show.id, admin_job.id, [ signed ])
    expect(ActiveStorage::Blob.find_signed(signed)).to be_nil
  end

  it "fails when the upload holds no audio" do
    empty = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("notes"), filename: "notes.txt", content_type: "text/plain"
    ).signed_id
    expect { described_class.new.perform(show.id, admin_job.id, [ empty ]) }
      .to raise_error(described_class::NoAudioError)
    expect(admin_job.reload.status).to eq("failed")
  end
end
