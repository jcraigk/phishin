# Applies a whole folder's worth of audio to a show in one pass, replacing the
# tracks that already had audio and filling the ones that did not.
#
# Every assignment is independent: a bad blob or a track that fails its ID3
# rewrite must not cost the admin the other twenty tracks that uploaded fine, so
# a failure is recorded on the job's payload and the batch carries on. The job
# only fails outright if nothing at all succeeded.
class Admin::BulkReplaceAudioJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id, assignments)
    @show = Show.find(show_id)
    @admin_job = AdminJob.find(admin_job_id)
    @results = { "replaced" => [], "filled" => [], "failed" => [] }

    @admin_job.run! do
      assignments.each_with_index do |assignment, index|
        apply(normalize(assignment))
        report(index + 1, assignments.size)
      end
      finalize(assignments.size)
    end
  end

  private

  # Sidekiq round-trips arguments through JSON, so keys arrive as strings whether
  # the caller passed symbols or not.
  def normalize(assignment)
    assignment.symbolize_keys
  end

  def apply(assignment)
    track = @show.tracks.find(assignment[:track_id])
    had_audio = track.mp3_audio.attached?
    blob = ActiveStorage::Blob.find_signed!(assignment[:signed_id])
    backup_path = TrackAudioReplacer.call(
      track:, blob:, operation: "bulk_replace_audio", admin_job: @admin_job
    )
    record_success(track, had_audio, backup_path)
  rescue StandardError => e
    @results["failed"] << {
      "track_id" => assignment[:track_id],
      "signed_id" => assignment[:signed_id],
      "error" => e.message
    }
  end

  def record_success(track, had_audio, backup_path)
    bucket = had_audio ? "replaced" : "filled"
    @results[bucket] << {
      "track_id" => track.id,
      "position" => track.position,
      "title" => track.title,
      "backup_path" => backup_path
    }.compact
  end

  def report(done, total)
    @admin_job.update!(
      progress: (done * 100.0 / total).round,
      message: "Processed #{done} of #{total} files"
    )
  end

  def finalize(total)
    @show.reload
    @show.update_audio_status_from_tracks!
    @show.save_duration
    @admin_job.payload.merge!(@results)
    @admin_job.save!

    failures = @results["failed"].size
    raise "All #{total} assignments failed" if failures == total && total.positive?
    @admin_job.update!(message: summary(total, failures))
  end

  def summary(total, failures)
    parts = [ "Replaced #{@results['replaced'].size}", "filled #{@results['filled'].size}" ]
    parts << "#{failures} failed" if failures.positive?
    "#{parts.join(', ')} of #{total} files"
  end
end
