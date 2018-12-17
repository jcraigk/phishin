# frozen_string_literal: true
namespace :phishnet do
  desc 'Sync jamcharts data'
  task sync_jamcharts: :environment do
    invalid_items = []
    missing_shows = []

    tag = Tag.where(name: 'Jamcharts').first
    songs = Song.all

    PHISHNET_URI = 'http://api.phish.net/api.js?api=2.0&method=pnet.jamcharts.all&apikey=448345A7B7688DDE43D0'
    uri = URI.parse(PHISHNET_URI)
    puts 'Fetching Jamcharts data from Phish.net API...'
    json = JSON[Net::HTTP.get_response(uri).body]

    pbar = ProgressBar.create(
      total: json.size,
      format: '%a %B %c/%C %p%% %E'
    )

    # Add missing tags for each entry
    json.each do |item|
      pbar.increment

      show = Show.unscoped.includes(:tracks).find_by(date: item['showdate'])
      next missing_shows << item['showdate'] if show.nil?
      track_matched = false
      show.tracks.order('position').each do |track|
        song = songs.find do |s|
          s.title.casecmp(item['song']).zero?
        end
        next if song.nil?

        st = SongsTrack.where(song_id: song.id, track_id: track.id).first
        next if st.nil?
        track_matched = true

        tt = TrackTag.find_by(track: track, tag: tag)
        next if tt&.notes == item['jamchart_description']

        if tt.present?
          tt.update(notes: item['jamchart_description'])
        else
          TrackTag.create(
            track: track,
            tag: tag,
            notes: item['jamchart_description']
          )
        end

        puts "#{show.date} => #{track.title} (#{track.id})"
      end

      if track_matched
        show.tags << tag unless show.tags.include?(tag)
      elsif show.missing || show.incomplete
        missing_shows << show.date
      else
        invalid_items << "#{item['showdate']} - #{item['song']}"
      end
    end

    pbar.finish

    puts "#{missing_shows.size} missing shows:\n" + missing_shows.join(', ')
    puts "#{invalid_items.size} invalid recs:\n" + invalid_items.join("\n")
  end
end
