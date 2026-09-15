class Admin::PublishShowJob
  include Sidekiq::Job

  class NotReadyError < StandardError; end

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      step(admin_job, 5, "Checking readiness") { ensure_ready!(show) }
      step(admin_job, 20, "Computing gaps") { GapService.call(show, update_previous: true) }
      step(admin_job, 30, "Applying bustout tags") { BustoutTagService.call(show) }
      warnings = Admin::PhishnetEnrichment.call(show) { |message| admin_job.update!(progress: 45, message:) }
      admin_job.payload["warnings"] = warnings
      step(admin_job, 85, "Creating announcement") { Announcement.announce_show!(show) }
      step(admin_job, 95, "Publishing") { show.update!(published: true) }
      step(admin_job, 99, "Clearing cache") { Rails.cache.clear }
    end
  end

  private

  def step(admin_job, progress, message)
    admin_job.progress!(progress, message)
    yield
  end

  def ensure_ready!(show)
    readiness = Admin::ShowReadiness.call(show)
    return if readiness[:ready]
    raise NotReadyError, "Not ready to publish: #{readiness[:issues].join('; ')}"
  end
end
