# Runs the tagin spreadsheet sync in the background, reporting which tag is in
# flight so the admin UI can show progress across the eleven sheet tabs.
class Admin::TaginSyncJob
  include Sidekiq::Job

  def perform(admin_job_id)
    @admin_job = AdminJob.find(admin_job_id)

    @admin_job.run! do
      results = TaginSyncService.call(progress: method(:report))
      finalize(results)
    end
  end

  private

  def report(tag_name, index, total)
    @admin_job.update!(
      progress: (index * 100.0 / total).round,
      message: "Syncing #{tag_name}"
    )
  end

  # Per-tag outcomes land on the payload so an admin can see exactly which tab
  # failed rather than only a count.
  def finalize(results)
    @admin_job.payload["tags"] = results.map { |result| result.transform_keys(&:to_s) }
    @admin_job.save!
    @admin_job.update!(message: summary(results))
  end

  def summary(results)
    failures = results.count { |result| result[:status] == "failed" }
    message = "Synced #{results.size - failures} of #{results.size} tags"
    failures.positive? ? "#{message}, #{failures} failed" : message
  end
end
