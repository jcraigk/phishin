require "rails_helper"

RSpec.describe Admin::PrepareBulkAudioJob do
  let(:show) { create(:show, date: "2024-07-19", taper_notes: nil) }
  let(:admin_job) { create(:admin_job, kind: "bulk_audio_prepare", show:) }
  let(:fixtures) { Rails.root.join("tmp/spec/bulk_prepare") }

  before do
    allow(Admin::TaperNotesAiTracklist).to receive(:call).and_return({})
    FileUtils.mkdir_p(fixtures)
    { "d1t01.flac" => [ 3, "Llama" ], "d1t02.flac" => [ 4, nil ] }.each do |name, (secs, title)|
      path = fixtures.join(name)
      next if File.exist?(path)
      args = [ "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
               "sine=frequency=440:duration=#{secs}" ]
      args += [ "-metadata", "title=#{title}" ] if title
      system(*args, "-c:a", "flac", path.to_s, exception: true)
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
    expect(blobs.map { it.filename.to_s }).to eq([ "Llama.mp3", "d1t02.mp3", "d2t01.mp3" ])
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

  it "prefers a taper notes title over the embedded tag" do
    show.update!(taper_notes: "Disc 1\n01. Suzie Greenberg")
    described_class.new.perform(show.id, admin_job.id, [ upload("d1t01.flac", "audio/flac") ])
    blob = ActiveStorage::Blob.find_signed!(admin_job.reload.payload["signed_ids"].first)
    expect(blob.filename.to_s).to eq("Suzie Greenberg.mp3")
  end

  it "asks the AI fallback about files the notes do not identify" do
    show.update!(taper_notes: "A lovely soundboard recording.")
    allow(Admin::TaperNotesAiTracklist).to receive(:call)
      .and_return({ "d1t02.flac" => "Foam" })
    described_class.new.perform(show.id, admin_job.id, [ upload("d1t02.flac", "audio/flac") ])
    blob = ActiveStorage::Blob.find_signed!(admin_job.reload.payload["signed_ids"].first)
    expect(blob.filename.to_s).to eq("Foam.mp3")
    expect(Admin::TaperNotesAiTracklist).to have_received(:call)
      .with(notes: "A lovely soundboard recording.", filenames: [ "d1t02.flac" ])
  end

  it "uses an uploaded notes txt as the title source and saves it to the show" do
    File.write(fixtures.join("info.txt"), "Disc 1\n01. Chalk Dust Torture")
    described_class.new.perform(
      show.id, admin_job.id,
      [ upload("info.txt", "text/plain"), upload("d1t01.flac", "audio/flac") ]
    )
    blob = ActiveStorage::Blob.find_signed!(admin_job.reload.payload["signed_ids"].first)
    expect(blob.filename.to_s).to eq("Chalk Dust Torture.mp3")
    expect(show.reload.taper_notes).to eq("Disc 1\n01. Chalk Dust Torture")
  end

  it "prefers an uploaded notes txt over stale show notes without overwriting them" do
    show.update!(taper_notes: "Disc 1\n01. Suzie Greenberg")
    File.write(fixtures.join("info.txt"), "Disc 1\n01. Chalk Dust Torture")
    described_class.new.perform(
      show.id, admin_job.id,
      [ upload("info.txt", "text/plain"), upload("d1t01.flac", "audio/flac") ]
    )
    blob = ActiveStorage::Blob.find_signed!(admin_job.reload.payload["signed_ids"].first)
    expect(blob.filename.to_s).to eq("Chalk Dust Torture.mp3")
    expect(show.reload.taper_notes).to eq("Disc 1\n01. Suzie Greenberg")
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
