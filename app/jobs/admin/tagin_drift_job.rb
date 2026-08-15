# Compares the tagin spreadsheet against the database and reports the
# differences, without changing either one.
#
# The sheet is the source of truth for these tags, and a sync clobbers the
# database to match it. That makes an unexplained difference worth seeing before
# it is overwritten: a tag added by hand in the admin UI disappears at the next
# sync, and a sheet row whose URL no longer resolves silently syncs nothing.
# This job is the read-only half of that workflow. It never writes a tag; the
# admin fixes the sheet and then runs the sync.
class Admin::TaginDriftJob
  include Sidekiq::Job

  # Raised when no tag could be compared, which points at credentials or the
  # spreadsheet id rather than at eleven separate sheet problems.
  class DriftFailed < StandardError; end

  # Attributes compared between a TrackTag and its sheet row, mapped to the
  # column headers TrackTagSyncService reads. Timestamps are held as seconds and
  # written from "mm:ss" cells, so both sides go through the same conversion.
  COMPARED = {
    "notes" => "Notes",
    "transcript" => "Transcript",
    "starts_at_second" => "Starts At",
    "ends_at_second" => "Ends At"
  }.freeze

  # Tags whose rows are identified by notes as well as url, matching how
  # TrackTagSyncService looks up an existing tag for them.
  MULTI_ENTRY_TAGS = %w[Tease Signal].freeze

  # Entries kept per category per tag. A first run against a stale database can
  # produce thousands of differences, and the payload is a jsonb column the UI
  # polls; the full counts are reported alongside the capped list.
  MAX_ENTRIES = 100

  def perform(admin_job_id)
    @admin_job = AdminJob.find(admin_job_id)
    @errors = []

    @admin_job.run! do
      drift = collect_drift
      raise DriftFailed, total_failure_message if total_failure?
      finalize(drift)
    end
  end

  private

  def collect_drift
    TAGIN_TAGS.each_with_index.with_object({}) do |(tag_name, index), drift|
      report_progress(tag_name, index)
      report = compare_tag(tag_name)
      drift[tag_name] = report if report && drifted?(report)
    end
  end

  def report_progress(tag_name, index)
    @admin_job.update!(
      progress: (index * 100.0 / TAGIN_TAGS.size).round,
      message: "Comparing #{tag_name}"
    )
  end

  # A tab that is missing or renamed costs its own tag only; the rest of the
  # comparison still reaches the admin.
  def compare_tag(tag_name)
    build_report(tag_name)
  rescue StandardError => e
    @errors << { "tag" => tag_name, "error" => e.message }
    nil
  end

  def build_report(tag_name)
    tag = Tag.find_by(name: tag_name)
    sheet_rows = fetch_rows(tag_name)
    db_tags = tag ? TrackTag.where(tag:).includes(track: :show) : TrackTag.none

    sheet_by_key = index_sheet_rows(sheet_rows, tag_name)
    db_by_key = index_db_tags(db_tags, tag_name)

    categorize(db_by_key, sheet_by_key)
  end

  def categorize(db_by_key, sheet_by_key)
    missing_in_sheet = (db_by_key.keys - sheet_by_key.keys).map { |key| db_entry(db_by_key[key]) }
    missing_in_db = (sheet_by_key.keys - db_by_key.keys).map { |key| sheet_entry(sheet_by_key[key]) }
    mismatched = mismatches(db_by_key, sheet_by_key)

    build_payload(missing_in_sheet:, missing_in_db:, mismatched:)
  end

  def build_payload(missing_in_sheet:, missing_in_db:, mismatched:)
    categories = { "missing_in_sheet" => missing_in_sheet, "missing_in_db" => missing_in_db, "mismatched" => mismatched }
    report = categories.transform_values { |entries| entries.take(MAX_ENTRIES) }
    report["counts"] = categories.transform_values(&:size)
    report["truncated"] = categories.any? { |_name, entries| entries.size > MAX_ENTRIES }
    report
  end

  def drifted?(report)
    report["counts"].values.any?(&:positive?)
  end

  def fetch_rows(tag_name)
    GoogleSpreadsheetFetcher.call(
      ENV["TAGIN_GSHEET_ID"], "#{tag_name}!A1:G5000", headers: true
    ).reject { |row| row["URL"].to_s.strip.empty? }
  end

  # Tease and Signal carry several tags per track, so their rows are keyed by
  # notes as well; keying those by url alone would report every one after the
  # first as drift.
  def index_sheet_rows(rows, tag_name)
    rows.index_by do |row|
      url = row["URL"].to_s.strip
      multi_entry?(tag_name) ? [ url, TaginRowNormalizer.normalized_notes(row["Notes"]) ] : url
    end
  end

  def index_db_tags(db_tags, tag_name)
    db_tags.index_by do |track_tag|
      multi_entry?(tag_name) ? [ track_tag.track.url, track_tag.notes ] : track_tag.track.url
    end
  end

  def multi_entry?(tag_name)
    tag_name.in?(MULTI_ENTRY_TAGS)
  end

  def db_entry(track_tag)
    track = track_tag.track
    {
      "url" => track.url,
      "track_title" => track.title,
      "show_date" => track.show.date.iso8601,
      "notes" => track_tag.notes
    }
  end

  # A sheet row is resolved through the same lookup the sync uses, so an entry
  # reports the track the sync would write to, or nulls when the url resolves to
  # nothing, which is itself the reason the row never synced.
  def sheet_entry(row)
    url = row["URL"].to_s.strip
    track = resolve_track(url)
    {
      "url" => url,
      "track_title" => track&.title,
      "show_date" => track&.show&.date&.iso8601,
      "notes" => TaginRowNormalizer.normalized_notes(row["Notes"])
    }
  end

  def resolve_track(url)
    Track.by_url(url)
  rescue URI::InvalidURIError
    nil
  end

  def mismatches(db_by_key, sheet_by_key)
    (db_by_key.keys & sheet_by_key.keys).filter_map do |key|
      track_tag = db_by_key[key]
      diffs = field_diffs(track_tag, sheet_by_key[key])
      next if diffs.empty?
      db_entry(track_tag).merge("field_diffs" => diffs)
    end
  end

  # Sheet values go through the transformations a sync applies before they are
  # compared, so a difference here is a difference in content rather than in
  # formatting.
  def field_diffs(track_tag, row)
    COMPARED.each_with_object({}) do |(attr, column), diffs|
      db_value = track_tag.public_send(attr)
      sheet_value = sheet_value_for(attr, row[column])
      diffs[attr] = { "db" => db_value, "sheet" => sheet_value } if db_value != sheet_value
    end
  end

  def sheet_value_for(attr, value)
    return TaginRowNormalizer.seconds_or_nil(value) if attr.end_with?("_second")
    TaginRowNormalizer.normalized_notes(value)
  end

  def finalize(drift)
    @admin_job.payload["drift"] = drift
    @admin_job.payload["errors"] = @errors
    @admin_job.save!
    @admin_job.update!(message: summary(drift))
  end

  def summary(drift)
    message = "#{drift.size} of #{TAGIN_TAGS.size} tags have drift"
    @errors.empty? ? message : "#{message}, #{@errors.size} could not be compared"
  end

  def total_failure?
    @errors.size == TAGIN_TAGS.size
  end

  def total_failure_message
    "Tagin drift report failed for all #{@errors.size} tags. Check " \
      "GOOGLE_SPREADSHEET_CREDS and TAGIN_GSHEET_ID. First error: #{@errors.first['error']}"
  end
end
