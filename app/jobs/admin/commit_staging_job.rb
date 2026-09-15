class Admin::CommitStagingJob
  include Sidekiq::Job

  PASSTHROUGH_TOLERANCE_S = 0.05
  TRACK_PROGRESS_CEILING = 90.0

  class Error < StandardError; end

  def perform(show_id, admin_job_id)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)
    @dir = Admin::StagingDir.new(@show)

    @admin_job.run! do
      raise Error, "Show #{@show.date} is already published" if @show.published?
      raise Error, "Show #{@show.date} has nothing staged" unless @show.staged_tracks.exists?
      raise Error, "timeline missing for #{@show.date}; ingest again" unless File.exist?(@dir.timeline)

      if @show.tracks.exists?
        @show.tracks.destroy_all
        @admin_job.update!(message: "Removed tracks left by an earlier commit")
      end

      Admin::ShowMatchAssigner.call(@show)
      create_tracks
      record_source
      enrich
      finalize
    end
  end

  private

  def staged
    @staged ||= @show.staged_tracks.ordered.to_a
  end

  def create_tracks
    staged.each_with_index do |staged_track, index|
      @admin_job.update!(
        progress: (index * TRACK_PROGRESS_CEILING / staged.size).round,
        message: "Rendering #{index + 1} of #{staged.size} · #{staged_track.title}"
      )
      path = render(staged_track)
      track = Track.new(
        show: @show, position: index + 1, title: staged_track.title,
        set: staged_track.set, audio_status: "complete"
      )
      track.songs = staged_track.songs
      track.save!
      File.open(path) { |io| track.attach_mp3!(io) }
    end
  end

  def render(staged_track)
    out = @dir.render_path(staged_track)
    if (source = passthrough_source(staged_track))
      FileUtils.mkdir_p(out.dirname)
      FileUtils.cp(@dir.source_path(source), out)
    else
      Admin::StagingRender.call(timeline: @dir.timeline, track: staged_track, out_path: out)
    end
    out
  end

  def passthrough_source(staged_track)
    return nil if staged_track.fade_in_s.positive? || staged_track.fade_out_s.positive?
    @show.staged_sources.find do |source|
      source.mp3? &&
        (source.offset_s - staged_track.start_s).abs <= PASSTHROUGH_TOLERANCE_S &&
        (source.end_s - staged_track.end_s).abs <= PASSTHROUGH_TOLERANCE_S
    end
  end

  def record_source
    url = @show.staging_source_url
    return if url.blank?
    notes = @show.taper_notes.to_s
    notes = [ notes.rstrip, "Source: #{url}" ].reject(&:empty?).join("\n\n") unless notes.include?(url)
    @show.update!(taper_notes: notes, staging_source_url: nil)
  end

  def enrich
    @warnings = Admin::PhishnetEnrichment.call(@show.reload) do |message|
      @admin_job.update!(progress: TRACK_PROGRESS_CEILING.round, message:)
    end
  end

  def finalize
    @show.discard_staging!
    @show.reload
    @show.update_audio_status_from_tracks!
    @show.save_duration
    @admin_job.payload["warnings"] = @warnings
    @admin_job.save!
    suffix = @warnings.any? ? " (#{@warnings.size} Phish.net step#{'s' unless @warnings.one?} failed)" : ""
    @admin_job.update!(message: "Committed #{staged.size} tracks#{suffix}")
  end
end
