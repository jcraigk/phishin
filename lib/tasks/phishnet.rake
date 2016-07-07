require "net/http"
require "uri"

namespace :phishnet do
  desc "Sync jamcharts data"
  task sync_jamcharts: :environment do
    invalid_items = []
    missing_shows = []

    tag = Tag.where(name: 'Jamcharts').first
    songs = Song.all

    uri = URI.parse("http://api.phish.net/api.js?api=2.0&method=pnet.jamcharts.all&apikey=448345A7B7688DDE43D0")
    json = JSON[Net::HTTP.get_response(uri).body]

    # Remove all current tags
    # ShowTag.where(tag_id: tag.id).all.map(&:destroy)
    # TrackTag.where(tag_id: tag.id).all.map(&:destroy)

    # Add missing tags for each entry
    json.each do |item|
      if show = Show.where(date: item['showdate']).includes(:tracks).first
        track_matched = false
        show.tracks.each do |track|
          if song = songs.detect { |s| s.title.downcase == item['song'].downcase }
            if SongsTrack.where(song_id: song.id, track_id: track.id).first
              track_matched = true
              unless track.tags.include?(tag)
                track.tags << tag
                track.save
                puts "#{show.date} => #{track.title} (track id #{track.id})"
              end
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
      else
        missing_shows << item['showdate']
      end
    end

    puts "#{missing_shows.size} missing shows:\n" + missing_shows.join(', ')
    puts "#{invalid_items.size} invalid recs:\n" + invalid_items.join("\n")
  end
end