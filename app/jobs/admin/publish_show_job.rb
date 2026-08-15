# Runs the pipeline ShowImporter::Orchestrator#save runs at import time, then makes
# the show public. Two of those steps are deliberately absent: InteractiveCoverArtService
# prompts on a terminal, and spreadsheet/tagin sync is its own on-demand button.
#
# The published flag flips LAST. Every side effect before it is recoverable by
# re-running the job on a draft; a show made public by a pipeline that then died
# would sit on the API missing gap data with nothing recording why.
class Admin::PublishShowJob
  include Sidekiq::Job

  class NotReadyError < StandardError; end

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      # The endpoint checks readiness too, but a draft can lose a track's audio
      # between that check and Sidekiq picking this up.
      step(admin_job, 5, "Checking readiness") { ensure_ready!(show) }
      step(admin_job, 20, "Computing gaps") { GapService.call(show, update_previous: true) }
      step(admin_job, 40, "Applying debut tags") { DebutTagService.call(show) }
      step(admin_job, 50, "Applying bustout tags") { BustoutTagService.call(show) }
      step(admin_job, 60, "Syncing lore") { LoreSyncService.call(date: show.date.to_s) }
      step(admin_job, 75, "Cleaning up staged audio") { cleanup_staged_audio(show) }
      step(admin_job, 85, "Creating announcement") { create_announcement(show) }
      step(admin_job, 95, "Publishing") { show.update!(published: true) }
      step(admin_job, 99, "Clearing cache") { Rails.cache.clear }
    end
  end

  private

  def step(admin_job, progress, message)
    admin_job.update!(progress:, message:)
    yield
  end

  def ensure_ready!(show)
    readiness = Admin::ShowReadiness.call(show)
    return if readiness[:ready]
    raise NotReadyError, "Not ready to publish: #{readiness[:issues].join('; ')}"
  end

  # Keyed on the url rather than the title so a venue rename between two runs
  # cannot slip a second announcement through.
  def create_announcement(show)
    url = "#{App.base_url}/#{show.date}"
    return if Announcement.exists?(url:)
    show_name = "#{show.date} at #{show.venue_name}"
    Announcement.create!(
      title: "New content: #{show_name}",
      description: "A new show has been added: #{show_name}",
      url:
    )
  end

  # A staged blob may have become a track's audio, so destroy the join row for
  # those and purge only the blobs nothing else points at.
  def cleanup_staged_audio(show)
    track_blob_ids = ActiveStorage::Attachment
                     .where(record_type: "Track", name: "mp3_audio")
                     .where(record_id: show.tracks.select(:id))
                     .pluck(:blob_id)
    show.staged_audio_attachments.each do |attachment|
      track_blob_ids.include?(attachment.blob_id) ? attachment.destroy : attachment.purge
    end
  end
end
