# Asks the prompt service for a fresh prompt, hue and style for a show. The
# service persists them itself (including clearing or setting the parent link for
# shows in a multi-night run), so this only mirrors the result onto the job for
# the editor to display without a refetch.
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
