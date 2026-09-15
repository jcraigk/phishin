class Admin::RegenerateCoverArtPromptJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      result = CoverArtPromptService.call(show, dry_run: true)
      admin_job.payload.merge!(
        "prompt" => result[:prompt],
        "suggestions" => result[:suggestions].transform_keys(&:to_s)
      )
      admin_job.save!
    end
  end
end
