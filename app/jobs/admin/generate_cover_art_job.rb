# Produces one new cover art candidate for a show. Candidates accumulate until
# an admin selects one, so this never touches show.cover_art itself -- hence the
# dry_run flag on the service, which uploads the generated image as a standalone
# blob and returns its URL without attaching it anywhere.
#
# Shows linked to a parent (a multi-night run shares one image) are short
# circuited here rather than in the service: the service's parent branch returns
# early with no URL, which would leave this job with nothing to attach.
class Admin::GenerateCoverArtJob
  include Sidekiq::Job

  def perform(show_id, admin_job_id)
    show = Show.find(show_id)
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      blob = show.cover_art_parent_show_id.present? ? parent_blob(show) : generated_blob(show)
      # Copying from a parent twice would attach the same blob twice and render
      # a duplicate card; the second copy is a no-op instead.
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

  def generated_blob(show)
    CoverArtBlobLocator.call(CoverArtImageService.call(show, dry_run: true))
  end
end
