require "google/apis/sheets_v4"

# Tag timestamps that fall past the end of the track they sit on.
#
# A track that was split, or had its audio replaced with a different transfer,
# leaves its tags pointing at a time the track no longer reaches. The player
# then seeks past the end, and the tag is unusable.
#
# The fix has to be made in the spreadsheet rather than the database: tagin:sync
# overwrites track_tags from the sheet, so a correction applied to the record
# alone is undone by the next sync.
module TaginTimestamps
  def self.seconds(str)
    return if str.blank?
    min, sec = str.to_s.split(":")
    (min.to_i * 60) + sec.to_i
  end

  def self.stamp(seconds)
    format("%d:%02d", seconds / 60, seconds % 60)
  end
end

namespace :tagin do
  desc "Report tag timestamps that fall past the end of their track " \
       "(rake tagin:stale_timestamps); TAGS=Tease,Banter limits the sheets read"
  task stale_timestamps: :environment do
    rows = TrackTag.where.not(starts_at_second: nil)
                   .or(TrackTag.where.not(ends_at_second: nil))
                   .includes(:tag, track: :show)
    stale = rows.select do |track_tag|
      duration = track_tag.track.duration.to_i / 1000.0
      next false unless duration.positive?
      [ track_tag.starts_at_second.to_i, track_tag.ends_at_second.to_i ].max > duration
    end
    puts "#{stale.size} timestamp(s) fall past the end of their track\n\n"
    stale.sort_by { -([ it.starts_at_second.to_i, it.ends_at_second.to_i ].max -
                      it.track.duration.to_i / 1000.0) }.each do |track_tag|
      duration = track_tag.track.duration.to_i / 1000.0
      last = [ track_tag.starts_at_second.to_i, track_tag.ends_at_second.to_i ].max
      puts format("  %s t%-3d %-26s %-8s %5ds of %5.0fs  (over by %.0fs)",
                  track_tag.track.show.date, track_tag.track.position,
                  track_tag.track.title.to_s.first(26), track_tag.tag.name,
                  last, duration, last - duration)
    end
  end

  desc "Clamp sheet timestamps that fall past the end of their track " \
       "(rake tagin:fix_timestamps); DRY_RUN=1 reports only, " \
       "TAGS=Tease,Banter limits the sheets written"
  task fix_timestamps: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    sheet_id = ENV.fetch("TAGIN_GSHEET_ID")
    service = Google::Apis::SheetsV4::SheetsService.new
    service.authorization =
      GoogleSheetsAuthorizer.call(scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS)

    tags = ENV["TAGS"].presence&.split(",")&.map(&:strip) || TAGIN_TAGS
    total = 0

    tags.each do |tag_name|
      values = service.get_spreadsheet_values(sheet_id, "#{tag_name}!A1:G5000").values.to_a
      next if values.size < 2
      header = values.first
      url_col = header.index("URL")
      start_col = header.index("Starts At")
      end_col = header.index("Ends At")
      next unless url_col && start_col

      updates = []
      values.drop(1).each_with_index do |row, index|
        url = row[url_col]
        next if url.blank?
        track = Track.by_url(url)
        next if track.nil?
        duration = track.duration.to_i / 1000.0
        next unless duration.positive?

        starts = TaginTimestamps.seconds(row[start_col])
        ends = end_col ? TaginTimestamps.seconds(row[end_col]) : nil
        next if [ starts.to_i, ends.to_i ].max <= duration

        # A second short of the end, so the marker still sits inside the audio.
        limit = [ (duration - 1).floor, 0 ].max
        row_number = index + 2
        if starts && starts > limit
          updates << [ "#{tag_name}!#{(65 + start_col).chr}#{row_number}", TaginTimestamps.stamp(limit) ]
        end
        if ends && ends > limit
          updates << [ "#{tag_name}!#{(65 + end_col).chr}#{row_number}", TaginTimestamps.stamp(limit) ]
        end
        puts format("  %-8s row %-5d %-46s %s..%s -> %s (track %.0fs)",
                    tag_name, row_number, url.sub("https://phish.in/", ""),
                    row[start_col], row[end_col], TaginTimestamps.stamp(limit), duration)
      end

      next if updates.empty?
      total += updates.size
      next if dry_run

      data = updates.map do |a1, value|
        Google::Apis::SheetsV4::ValueRange.new(range: a1, values: [ [ value ] ])
      end
      service.batch_update_values(
        sheet_id,
        Google::Apis::SheetsV4::BatchUpdateValuesRequest.new(
          value_input_option: "RAW", data:
        )
      )
    end

    puts "\n#{dry_run ? 'DRY RUN: would update' : 'Updated'} #{total} cell(s)"
    puts "Run `rake tagin:sync` to pull the corrected values into track_tags." unless dry_run
  end
end
