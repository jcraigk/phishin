class Admin::GenerateCoverArtJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id, prompt = nil)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      blob = show.cover_art_parent_show_id.present? ? parent_blob(show) : generated_blob(show, prompt)
      unless show.cover_art_candidates_attachments.any? { it.blob_id == blob.id }
        show.cover_art_candidates.attach(blob)
      end
      admin_job.payload["blob_key"] = blob.key
      admin_job.save!
    end
  end

  private

  def parent_blob(show)
    parent = Show.find(show.cover_art_parent_show_id)
    raise "Parent show has no cover art" unless parent.cover_art.attached?
    parent.cover_art.blob
  end

  def generated_blob(show, prompt)
    CoverArtBlobLocator.call(
      CoverArtImageService.call(show, dry_run: true, prompt_override: prompt)
    )
  end
end
