require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"
require "csv"

namespace :tagin do
  desc "Sync data from remote spreadsheet"
  task sync: :environment do
    TAGIN_TAGS.each do |tag_name|
      puts "========================"
      puts " Syncing Tag: #{tag_name}"
      puts "========================"

      range = "#{tag_name}!A1:G5000"
      data = GoogleSpreadsheetFetcher.call(ENV["TAGIN_GSHEET_ID"], range, headers: true)

      TrackTagSyncService.call(tag_name, data)
    end
  end

  desc "Sync jam_starts_at_second data from spreadsheet"
  task jamstart: :environment do
    data = GoogleSpreadsheetFetcher.call(ENV["TAGIN_GSHEET_ID"], "JAMSTART!A1:G5000", headers: true)
    data.each do |row|
      track = Track.by_url(row["URL"])
      next puts "Invalid track: #{row['URL']}" if track.blank?
      jam_starts_at_second =
          if str.include?(":")
            min, sec = str.split(":")
            (min.to_i * 60) + sec.to_i
          else
            nil
          end
      track.update!(jam_starts_at_second:)
      print "."
    end
  end

  desc "Calculate Grind days counts"
  task grind: :environment do
    include ActionView::Helpers::NumberHelper

    first_date = Date.parse("2009-03-06");
    first_days_lived = {
      "Page" => 16_730,
      "Fish" => 16_086,
      "Trey" => 16_228,
      "Mike" => 15_982
    }

    csv_data = []
    Track.joins(:show)
         .where("tracks.title = ?", "Grind")
         .where("shows.date > ?", first_date)
         .order("shows.date asc")
         .each do |track|
      delta = (track.show.date - first_date).to_i
      total = 0
      notes = first_days_lived.map do |person, count|
        person_total = count + delta
        total += person_total
        "#{person}: #{number_with_delimiter(person_total)} days"
      end.join("\n")
      notes += "\nGrand total: #{number_with_delimiter(total)} days"

      csv_data << [track.url, "", "", notes]
    end

    CSV.open("#{Rails.root}/tmp/grind.csv", "w") do |csv|
      csv_data.each do |d|
        csv << d
      end
    end
  end
end
