class Admin::EditCoverArtJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id, source_blob_key, edit_prompt)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      url = CoverArtImageService.call(show, dry_run: true, source_blob_key:, edit_prompt:)
      blob = CoverArtBlobLocator.call(url)
      show.cover_art_candidates.attach(blob)
      admin_job.payload["blob_key"] = blob.key
      admin_job.save!
    end
  end
end
