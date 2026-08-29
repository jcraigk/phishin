# Turns a staged show into tracks. Each staged track is rendered once from the
# lossless timeline through lame, which is the only lossy pass any of this
# audio takes. A staged track that exactly covers one mp3 source with no fades
# is copied through instead, so an mp3-sourced show imports without a re-encode
# just as the mp3 import path always has.
#
# Nothing here is transactional across tracks on purpose: an attach on a
# persisted record defers its upload to after_commit, so attaching inside a
# transaction leaves process_mp3_audio probing a file that is not there yet.
# Tracks are created one at a time in position order, the same way
# ImportShowJob does it, and a failure leaves the show with the tracks created
# so far plus its staging intact for a re-run after the cause is fixed.
class Admin::CommitStagingJob
  include Sidekiq::Job

  # A span within this of a source's edges counts as the whole source. Probed
  # durations carry millisecond noise; a real edit is never this small.
  PASSTHROUGH_TOLERANCE_S = 0.05
  TRACK_PROGRESS_CEILING = 90.0

  class Error < StandardError; end

  def perform(show_id, admin_job_id)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)
    @dir = Admin::StagingDir.new(@show)

    @admin_job.run! do
      raise Error, "Show #{@show.date} already has tracks" if @show.tracks.exists?
      raise Error, "Show #{@show.date} has nothing staged" unless @show.staged_tracks.exists?
      raise Error, "timeline missing for #{@show.date}; ingest again" unless File.exist?(@dir.timeline)

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

  # The Matcher is only asked for venue and tour here; titles were settled in
  # staging. A date Phish.net does not know leaves both for the admin to set.
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
