require 'net/http'
require 'uri'

namespace :phishnet do
  desc 'Sync jamcharts data'
  task sync_jamcharts: :environment do
    invalid_items = []
    missing_shows = []

    tag = Tag.where(name: 'Jamcharts').first
    songs = Song.all

    PHISHNET_URI = 'http://api.phish.net/api.js?api=2.0&method=pnet.jamcharts.all&apikey=448345A7B7688DDE43D0'.freeze
    uri = URI.parse(PHISHNET_URI)
    json = JSON[Net::HTTP.get_response(uri).body]

    # Add missing tags for each entry
    json.each do |item|
      show = Show.where(date: item['showdate']).includes(:tracks).first
      next missing_shows << item['showdate'] if show.nil?

      track_matched = false
      show.tracks.each do |track|
        song = songs.find do |s|
          s.title.casecmp(item['song']) > -1 ||
            (!s.alt_title.nil? && s.alt_title.casecmp(item['song']) > -1)
        end
        next if song.nil?

        st = SongsTrack.where(song_id: song.id, track_id: track.id).first
        next if st.nil?
        next if track.tags.include?(tag)

        track.tags << tag
        track.save
        puts "#{show.date} => #{track.title} (track id #{track.id})"

        track_matched = true
      end

      if track_matched
        show.tags << tag unless show.tags.include?(tag)
      elsif show.missing || show.incomplete
        missing_shows << show.date
      else
        invalid_items << "#{item['showdate']} - #{item['song']}"
      end
    end

    puts "#{missing_shows.size} missing shows:\n" + missing_shows.join(', ')
    puts "#{invalid_items.size} invalid recs:\n" + invalid_items.join("\n")
  end
end
