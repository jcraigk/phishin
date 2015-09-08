require "net/http"
require "uri"

namespace :phishnet do
  desc "Sync jamcharts data"
  task sync_jamcharts: :environment do
    invalid_items = []
    missing_shows = []

    tag = Tag.where(name: 'Jamcharts').first

    uri = URI.parse("http://api.phish.net/api.js?api=2.0&method=pnet.jamcharts.all&apikey=448345A7B7688DDE43D0")
    response = Net::HTTP.get_response(uri)
    json = JSON[response.body]
    json.each do |item|
      show = Show.where(date: item['showdate']).includes(:tracks).first
      track_matched = false
      show.tracks.each do |track|
        if track.title.include? item['song']
          track_matched = true
          unless track.tags.include?(tag)
            track.tags << tag
            track.save
            puts "#{show.date} => #{track.title} (track id #{track.id})"
          end
        end
      end
      if track_matched
        show.tags << tag unless show.tags.include?(tag)
      else
        if show.missing or show.incomplete
          missing_shows << show.date
        else
          invalid_items << "#{item['showdate']} - #{item['song']}"
        end
      end
    end

    puts "#{missing_shows.size} missing shows:\n" + missing_shows.join(', ')
    puts "#{invalid_items.size} invalid recs:\n" + invalid_items.join("\n")
  end
end