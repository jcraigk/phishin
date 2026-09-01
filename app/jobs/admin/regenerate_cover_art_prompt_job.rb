class Admin::RegenerateCoverArtPromptJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      CoverArtPromptService.call(show)
      show.reload
      admin_job.payload.merge!(
        "prompt" => show.cover_art_prompt,
        "hue" => show.cover_art_hue,
        "style" => show.cover_art_style
      )
      admin_job.save!
    end
  end
end
