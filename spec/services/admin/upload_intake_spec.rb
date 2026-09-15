require "rails_helper"

RSpec.describe Admin::UploadIntake do
  let(:dir) { Dir.mktmpdir("upload_intake") }
  let(:intake) { described_class.new(dir) }

  after { FileUtils.rm_rf(dir) }

  def upload(name, content)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename: name, content_type: "application/octet-stream").signed_id
  end

  it "receives uploads and lists audio files and notes" do
    intake.receive([ upload("b.FLAC", "x"), upload("a.mp3", "x"), upload("info.txt", "Taper: someone") ])
    expect(intake.audio_files.map { File.basename(it) }).to eq([ "a.mp3", "b.FLAC" ])
    expect(intake.notes_text).to eq("Taper: someone")
  end

  it "unpacks archives and reports their name" do
    Dir.mktmpdir do |src|
      File.write(File.join(src, "d1t01.flac"), "x")
      File.write(File.join(src, "notes.txt"), "hello")
      zip = File.join(src, "show.zip")
      system("bsdtar", "-a", "-cf", zip, "-C", src, "d1t01.flac", "notes.txt", exception: true)
      names = []
      intake.receive([ upload("show.zip", File.binread(zip)) ]) { |name| names << name }
      expect(names).to eq([ "show.zip" ])
    end
    expect(intake.audio_files.map { File.basename(it) }).to eq([ "d1t01.flac" ])
    expect(intake.notes_text).to eq("hello")
  end

  it "ignores symlinked files so an archive cannot read server files into notes" do
    Dir.mktmpdir do |src|
      File.write(File.join(src, "d1t01.flac"), "x")
      File.symlink("/etc/hosts", File.join(src, "notes.txt"))
      File.symlink("/etc/hosts", File.join(src, "d1t02.flac"))
      zip = File.join(src, "show.zip")
      system("bsdtar", "-a", "-cf", zip, "-C", src, "d1t01.flac", "notes.txt", "d1t02.flac", exception: true)
      intake.receive([ upload("show.zip", File.binread(zip)) ])
    end
    expect(intake.audio_files.map { File.basename(it) }).to eq([ "d1t01.flac" ])
    expect(intake.notes_text).to eq("")
  end

  it "raises when an archive unpacks nothing" do
    Dir.mktmpdir do |src|
      zip = File.join(src, "empty.zip")
      Dir.mktmpdir { |scratch| system("bsdtar", "-a", "-cf", zip, "-C", scratch, ".", exception: true) }
      expect { intake.receive([ upload("empty.zip", File.binread(zip)) ]) }
        .to raise_error(described_class::Error, /unpacked nothing/)
    end
  end
end
