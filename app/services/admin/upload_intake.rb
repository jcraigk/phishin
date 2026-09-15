class Admin::UploadIntake
  AUDIO_EXTENSIONS = StagedSource::FORMATS
  ARCHIVE_EXTENSIONS = %w[zip rar 7z tar tgz].freeze

  class Error < StandardError; end

  def self.extension(path)
    File.extname(path.to_s).delete(".").downcase
  end

  def initialize(dir)
    @dir = Pathname(dir)
  end

  def receive(signed_ids)
    Array(signed_ids).each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      dest = @dir.join(File.basename(Show.original_filename(blob)))
      File.open(dest, "wb") { |file| blob.download { |chunk| file.write(chunk) } }
      blob.purge
      next unless ARCHIVE_EXTENSIONS.include?(self.class.extension(dest))
      yield File.basename(dest) if block_given?
      unpack(dest)
    end
    self
  end

  def audio_files
    files.select { AUDIO_EXTENSIONS.include?(self.class.extension(it)) }.sort_by(&:downcase)
  end

  def notes_text
    files.select { self.class.extension(it) == "txt" }.sort
         .map { File.read(it, encoding: "UTF-8", invalid: :replace).scrub }
         .join("\n\n").strip
  end

  private

  def files
    Dir.glob(@dir.join("**/*")).select do |path|
      File.file?(path) && !File.symlink?(path) &&
        !path.include?("__MACOSX") && !File.basename(path).start_with?(".")
    end
  end

  def unpack(archive)
    basename = File.basename(archive)
    system("bsdtar", "-xf", archive.to_s, "-C", @dir.to_s) or raise Error, "could not unpack #{basename}"
    FileUtils.rm_f(archive)
    raise Error, "#{basename} unpacked nothing" if files.empty?
  end
end
