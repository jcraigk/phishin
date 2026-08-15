# Runs an AI edit of an existing image (a candidate, or the show's current cover
# art) into a brand new candidate. The source blob is only read, never modified:
# an edit that disappoints must leave the admin with the image they started from.
#
# Unlike generation this ignores cover_art_parent_show_id -- the service treats a
# request carrying both source_blob_key and edit_prompt as an edit regardless of
# any parent link, and an admin editing a specific image means that image.
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
