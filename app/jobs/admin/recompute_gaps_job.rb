class Admin::RecomputeGapsJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      GapService.call(show, update_previous: true)
    end
  end
end
