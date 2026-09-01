class TaginSyncService < ApplicationService
  class SyncFailed < StandardError; end

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

  def total_failure_message
    "Tagin sync failed for all #{@results.size} tags. Check GOOGLE_SPREADSHEET_CREDS " \
      "and TAGIN_GSHEET_ID. First error: #{@results.first[:error]}"
  end
end
