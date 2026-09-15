class Admin::IngestStagingJob
  include Sidekiq::Job

  sidekiq_options retry: 0

  PROXY_BITRATE = "128k".freeze

  class Error < StandardError; end
  class NoAudioError < Error; end

  def perform(show_id, admin_job_id, signed_ids, archive_item, discard_show_on_failure = false)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)
    @dir = Admin::StagingDir.new(@show)

    begin
      run_ingest(signed_ids, archive_item)
    rescue AdminJob::Cancelled
      discard_import(discard_show_on_failure)
    rescue StandardError
      discard_empty_draft if discard_show_on_failure
      raise
    end
  end

  private

  def run_ingest(signed_ids, archive_item)
    @admin_job.run! do
      raise Error, "Show #{@show.date} already has tracks" if @show.tracks.exists?
      @show.discard_staging!
      @dir.reset!

      intake = Admin::UploadIntake.new(@dir.incoming)
      notes = archive_item.present? ? fetch_archive(archive_item) : receive_uploads(intake, signed_ids)
      files = intake.audio_files
      raise NoAudioError, "no audio files found in the upload" if files.empty?

      sources = place_sources(files)
      build_timeline(sources)
      build_peaks
      render_proxies(sources)
      create_tracks(sources)
      Admin::ShowMatchAssigner.call(@show)
      @show.update!(taper_notes: notes) if notes.present? && @show.taper_notes.blank?
      @admin_job.update!(message: "Staged #{sources.size} files")
    end
  end

  def discard_import(discard_show)
    @show.reload.discard_staging!
    discard_empty_draft if discard_show
  end

  def discard_empty_draft
    @show.reload
    return if @show.published? || @show.tracks.exists?
    @admin_job.update!(show_id: nil)
    @show.destroy!
  rescue StandardError
    nil
  end

  def progress(pct, message)
    @admin_job.progress!(pct, message)
  end

  def fetch_archive(identifier)
    @admin_job.payload["headline"] = identifier
    @admin_job.save!
    progress(5, "Fetching file list")
    item = Admin::ArchiveItem.new(identifier)
    item.download_to(@dir.incoming) do |name, index, total|
      pct = 5 + (index.to_f / total * 55).round
      progress(pct, "Downloading #{index + 1} of #{total} · #{File.basename(name)}")
    end
    @show.update!(staging_source_url: item.details_url)
    item.description
  end

  def receive_uploads(intake, signed_ids)
    progress(5, "Receiving upload")
    intake.receive(signed_ids) { |name| progress(10, "Unpacking #{name}") }
    intake.notes_text
  rescue Admin::UploadIntake::Error => e
    raise Error, e.message
  end

  def place_sources(files)
    offset = 0.0
    files.each_with_index.map do |path, index|
      progress(15 + (index * 15 / files.size), "Reading #{File.basename(path)}")
      duration = Admin::AudioProbe.duration_s(path)
      source = @show.staged_sources.create!(
        position: index + 1, filename: File.basename(path), format: Admin::UploadIntake.extension(path),
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

  def build_peaks
    progress(45, "Building waveform")
    Admin::StagingPeaks.generate(@dir.timeline, @dir.peaks)
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
        position: source.position, start_s: source.offset_s, end_s: source.end_s,
        original_start_s: source.offset_s, original_end_s: source.end_s, **guess
      )
    end
    StagedTrack.normalize_sets!(@show)
    StagedTrack.normalize_edge_fades!(@show)
  end

  def run_ffmpeg(args)
    _out, err, status = Open3.capture3("ffmpeg", "-y", "-v", "error", *args)
    raise Error, "ffmpeg failed for #{@show.date}: #{err}" unless status.success?
  end
end
