# Pulls the tagin spreadsheet into the database, one sheet tab per tag.
#
# The spreadsheet is the source of truth for these tag types, so a sync clobbers
# local edits to them. That is intentional; drift is meant to be fixed in the
# sheet, not in the database.
#
# Each tag is synced independently. A single tab that is missing, renamed, or
# holding a tag name absent from the database must not cost the admin the other
# ten tabs that read fine, so a failure is recorded against that tag and the run
# continues. Losing every tag is a different animal: that is a credentials or
# spreadsheet-id problem rather than eleven separate sheet problems, and calling
# it a success would tell an admin the sync worked when nothing synced at all.
class TaginSyncService < ApplicationService
  # Raised when no tag synced, so the caller can surface a failure rather than
  # report a run that accomplished nothing as done.
  class SyncFailed < StandardError; end

  # `progress` receives (tag_name, index, total) before each tag is fetched.
  option :progress, optional: true, default: -> { nil }

  def call
    @results = TAGIN_TAGS.each_with_index.map do |tag_name, index|
      progress&.call(tag_name, index, TAGIN_TAGS.size)
      sync_tag(tag_name)
    end

    raise SyncFailed, total_failure_message if total_failure?

    Rails.cache.clear
    @results
  end

  private

  def sync_tag(tag_name)
    data = GoogleSpreadsheetFetcher.call(
      ENV["TAGIN_GSHEET_ID"], "#{tag_name}!A1:G5000", headers: true
    )
    TrackTagSyncService.call(tag_name, data)
    { tag: tag_name, status: "ok" }
  rescue StandardError => e
    { tag: tag_name, status: "failed", error: e.message }
  end

  def total_failure?
    @results.any? && @results.all? { |result| result[:status] == "failed" }
  end

  # Names the credentials an admin has to go check, since an expired or absent
  # refresh token is the usual reason for every tab failing at once.
  def total_failure_message
    "Tagin sync failed for all #{@results.size} tags. Check GOOGLE_SPREADSHEET_CREDS " \
      "and TAGIN_GSHEET_ID. First error: #{@results.first[:error]}"
  end
end
