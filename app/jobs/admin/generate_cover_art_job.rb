class Admin::GenerateCoverArtJob
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(show_id, admin_job_id, prompt = nil, model = nil)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      blob = generated_blob(show, prompt, model)
      unless show.cover_art_candidates_attachments.any? { it.blob_id == blob.id }
        show.cover_art_candidates.attach(blob)
      end
      admin_job.payload["blob_key"] = blob.key
      admin_job.save!
    end
  end

  private

  def generated_blob(show, prompt, model)
    CoverArtBlobLocator.call(
      CoverArtImageService.call(show, dry_run: true, prompt_override: prompt, model:)
    )
  end
end
