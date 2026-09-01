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

      assign_venue_and_tour
      create_tracks
      record_source
      finalize
    end
  end

  private

  def staged
    @staged ||= @show.staged_tracks.ordered.to_a
  end

  def assign_venue_and_tour
    match = ShowImporter::Matcher.call(date: @show.date.to_s, filenames: [])
    @show.venue = match.venue if match.venue
    @show.tour = match.tour if match.tour
    @show.save!
  rescue ShowImporter::ShowInfo::NotFoundError
    nil
  end

  def create_tracks
    staged.each_with_index do |staged_track, index|
      @admin_job.update!(
        progress: (index * TRACK_PROGRESS_CEILING / staged.size).round,
        message: "Rendering #{staged_track.title}"
      )
      path = render(staged_track)
      track = Track.new(
        show: @show, position: index + 1, title: staged_track.title,
        set: staged_track.set, audio_status: "complete"
      )
      track.songs << staged_track.song if staged_track.song
      track.save!
      track.mp3_audio.attach(io: File.open(path), filename: track.friendly_filename, content_type: "audio/mpeg")
      track.process_mp3_audio
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

  def finalize
    @show.staged_tracks.destroy_all
    @show.staged_sources.destroy_all
    @dir.remove!
    @show.reload
    @show.update_audio_status_from_tracks!
    @show.save_duration
    @admin_job.update!(message: "Committed #{staged.size} tracks")
  end
end
