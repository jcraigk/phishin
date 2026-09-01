class Admin::PrepareBulkAudioJob
  include Sidekiq::Job
  include LameEncoding

  AUDIO_EXTENSIONS = %w[flac shn wav aiff mp3].freeze
  ARCHIVE_EXTENSIONS = %w[zip rar 7z tar tgz].freeze

  class Error < StandardError; end
  class NoAudioError < Error; end

  def perform(show_id, admin_job_id, signed_ids)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)

    @admin_job.run! do
      Dir.mktmpdir("bulk_audio_prepare") do |dir|
        @dir = dir
        receive_uploads(signed_ids)
        files = audio_files
        raise NoAudioError, "no audio files found in the upload" if files.empty?
        titles = titles_for(files)
        ids = files.map.with_index do |path, index|
          @admin_job.update!(
            progress: (index * 100.0 / files.size).round,
            message: "Preparing #{File.basename(path)}"
          )
          upload_as_mp3(path, titles[path]).signed_id
        end
        @admin_job.update!(
          message: "Prepared #{files.size} files",
          payload: @admin_job.payload.merge("signed_ids" => ids)
        )
      end
    end
  end

  private

  def receive_uploads(signed_ids)
    Array(signed_ids).each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      dest = File.join(@dir, File.basename(Show.original_filename(blob)))
      File.open(dest, "wb") { |file| blob.download { |chunk| file.write(chunk) } }
      blob.purge
      unpack(dest) if ARCHIVE_EXTENSIONS.include?(extension(dest))
    end
  end

  def unpack(archive)
    system("bsdtar", "-xf", archive, "-C", @dir) or
      raise Error, "could not unpack #{File.basename(archive)}"
    FileUtils.rm_f(archive)
  end

  def extension(path)
    File.extname(path.to_s).delete(".").downcase
  end

  def audio_files
    Dir.glob(File.join(@dir, "**/*")).select do |path|
      File.file?(path) && !File.symlink?(path) &&
        AUDIO_EXTENSIONS.include?(extension(path)) &&
        !path.include?("__MACOSX") && !File.basename(path).start_with?(".")
    end.sort_by(&:downcase)
  end

  def uploaded_notes
    @uploaded_notes ||= Dir.glob(File.join(@dir, "**/*.txt")).select do |path|
      File.file?(path) && !path.include?("__MACOSX") &&
        !File.basename(path).start_with?(".")
    end.sort.map { File.read(it).scrub }.join("\n")
  end

  def titles_for(files)
    notes = uploaded_notes.presence || @show.taper_notes.to_s
    @show.update!(taper_notes: notes) if uploaded_notes.present? && @show.taper_notes.blank?
    parsed = Admin::TaperNotesTracklist.call(notes)
    titles = files.index_with do |path|
      key = Admin::TaperNotesTracklist.key_for(path)
      key && parsed[key]
    end
    unresolved = titles.select { |_path, title| title.nil? }.keys
    if notes.present? && unresolved.any?
      by_basename = Admin::TaperNotesAiTracklist.call(
        notes:, filenames: unresolved.map { File.basename(it) }
      )
      unresolved.each { |path| titles[path] ||= by_basename[File.basename(path)] }
    end
    titles.transform_values { |title| title&.tr("/", "-") }
  end

  def upload_as_mp3(path, title)
    filename = "#{title || embedded_title(path) || File.basename(path, '.*')}.mp3"
    out = path
    unless extension(path) == "mp3"
      out = File.join(@dir, "#{SecureRandom.hex(4)}.mp3")
      render_via_lame(out, [ "-i", path ])
    end
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(out), filename:, content_type: "audio/mpeg"
    )
  end

  def embedded_title(path)
    out, _err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format_tags=title",
      "-of", "csv=p=0", path
    )
    return nil unless status.success?
    out.strip.tr("/", "-").presence
  end

  def label
    @show.date.to_s
  end
end
