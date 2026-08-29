# Turns an upload or an archive.org item into a staged show: every audio file
# laid end to end on one lossless timeline, a browser-playable proxy per file,
# and a staged track per file with a first-guess title.
#
# The timeline is built with ffmpeg's concat filter rather than the concat
# demuxer because the filter resamples inputs to one format, so a set whose
# files disagree on sample rate still joins. mp3 inputs decode with LAME
# gapless trimming, which keeps their seams sample-accurate.
#
# Re-running on a show replaces its staging wholesale: this is the start of a
# review, not an edit to one.
class Admin::IngestStagingJob
  include Sidekiq::Job

  AUDIO_EXTENSIONS = StagedSource::FORMATS.freeze
  ARCHIVE_EXTENSIONS = %w[zip rar 7z tar tgz].freeze
  PROXY_BITRATE = "128k".freeze

  class Error < StandardError; end
  class NoAudioError < Error; end

  def perform(show_id, admin_job_id, signed_ids, archive_item)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)
    @dir = Admin::StagingDir.new(@show)

    @admin_job.run! do
      raise Error, "Show #{@show.date} already has tracks" if @show.tracks.exists?
      @show.staged_tracks.destroy_all
      @show.staged_sources.destroy_all
      @dir.reset!

      notes = archive_item.present? ? fetch_archive(archive_item) : receive_uploads(signed_ids)
      files = audio_files
      raise NoAudioError, "no audio files found in the upload" if files.empty?

      sources = place_sources(files)
      build_timeline(sources)
      render_proxies(sources)
      create_tracks(sources)
      @show.update!(taper_notes: notes) if notes.present? && @show.taper_notes.blank?
      @admin_job.update!(message: "Staged #{sources.size} files")
    end
  end

  private

  def progress(pct, message)
    @admin_job.update!(progress: pct, message:)
  end

  def fetch_archive(identifier)
    progress(5, "Fetching #{identifier} from archive.org")
    item = Admin::ArchiveItem.new(identifier)
    item.download_to(@dir.incoming)
    @show.update!(staging_source_url: item.details_url)
    item.description
  end

  # Blobs are throwaway transport: purged as soon as their bytes are on disk.
  def receive_uploads(signed_ids)
    progress(5, "Receiving upload")
    Array(signed_ids).each do |signed_id|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      dest = @dir.incoming.join(Show.original_filename(blob))
      File.open(dest, "wb") { |f| blob.download { |chunk| f.write(chunk) } }
      blob.purge
      unpack(dest) if ARCHIVE_EXTENSIONS.include?(extension(dest))
    end
    notes_text
  end

  def unpack(archive)
    progress(10, "Unpacking #{File.basename(archive)}")
    system("bsdtar", "-xf", archive.to_s, "-C", @dir.incoming.to_s) or
      raise Error, "could not unpack #{File.basename(archive)}"
    FileUtils.rm_f(archive)
  end

  def extension(path)
    File.extname(path.to_s).delete(".").downcase
  end

  # Sorted by full relative path so a multi-disc set keeps its disc order, and
  # skipping Finder's resource forks and dotfiles.
  def audio_files
    Dir.glob(@dir.incoming.join("**/*")).select do |path|
      File.file?(path) && AUDIO_EXTENSIONS.include?(extension(path)) &&
        !path.include?("__MACOSX") && !File.basename(path).start_with?(".")
    end.sort_by { |path| path.downcase }
  end

  def notes_text
    Dir.glob(@dir.incoming.join("**/*.txt")).sort.map { File.read(it, encoding: "UTF-8", invalid: :replace) }
       .join("\n\n").strip
  end

  def place_sources(files)
    offset = 0.0
    files.each_with_index.map do |path, index|
      progress(15 + (index * 15 / files.size), "Reading #{File.basename(path)}")
      duration = Admin::AudioProbe.duration_s(path)
      source = @show.staged_sources.create!(
        position: index + 1, filename: File.basename(path), format: extension(path),
        offset_s: offset.round(3), duration_s: duration.round(3)
      )
      FileUtils.mv(path, @dir.source_path(source))
      offset += duration
      source
    end
  end

  def build_timeline(sources)
    progress(35, "Joining #{sources.size} files into one timeline")
    inputs = sources.flat_map { [ "-i", @dir.source_path(it).to_s ] }
    labels = sources.each_index.map { "[#{it}:a]" }.join
    filter = "#{labels}concat=n=#{sources.size}:v=0:a=1[out]"
    run_ffmpeg(inputs + [ "-filter_complex", filter, "-map", "[out]", "-c:a", "flac", @dir.timeline.to_s ])
  end

  def render_proxies(sources)
    sources.each_with_index do |source, index|
      next if source.mp3?
      progress(50 + (index * 40 / sources.size), "Rendering preview for #{source.filename}")
      run_ffmpeg([ "-i", @dir.source_path(source).to_s, "-codec:a", "libmp3lame",
                   "-b:a", PROXY_BITRATE, @dir.proxy_path(source).to_s ])
    end
  end

  def create_tracks(sources)
    progress(92, "Matching titles")
    guesses = Admin::StagingTitler.call(show: @show, sources:)
    sources.zip(guesses).each do |source, guess|
      @show.staged_tracks.create!(
        position: source.position, start_s: source.offset_s, end_s: source.end_s, **guess
      )
    end
  end

  def run_ffmpeg(args)
    _out, err, status = Open3.capture3("ffmpeg", "-y", "-v", "error", *args)
    raise Error, "ffmpeg failed for #{@show.date}: #{err}" unless status.success?
  end
end
