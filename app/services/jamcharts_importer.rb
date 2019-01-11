# frozen_string_literal: true
class JamchartsImporter
  attr_reader :api_key, :invalid_items, :missing_shows

  def initialize(api_key)
    @api_key = api_key
  end

  def call
    @invalid_items = []
    @missing_shows = []
    sync_jamcharts
  end

  private

  def jamcharts_tag
    @jamcharts_tag ||= Tag.where(name: 'Jamcharts').first
  end

  def phishnet_uri
    URI.parse("http://api.phish.net/api.js?api=2.0&method=pnet.jamcharts.all&apikey=#{api_key}")
  end

  def songs
    @songs ||= Song.all
  end

  def jamcharts_as_json
    @jamcharts_as_json ||= JSON[Net::HTTP.get_response(phishnet_uri).body]
  end

  def create_progress_bar
    ProgressBar.create(total: jamcharts_as_json.size, format: '%a %B %c/%C %p%% %E')
  end

  def find_show_by_date(date)
    Show.unscoped.includes(:tracks).find_by(date: date)
  end

  def sync_jamcharts
    pbar = create_progress_bar

    jamcharts_as_json.each do |item|
      show = find_show_by_date(item['showdate'])
      next @missing_shows << item['showdate'] unless show
      handle_item(item, show)
      pbar.increment
    end

    pbar.finish
    print_results
  end

  def print_results
    puts "#{missing_shows.size} missing shows:\n" + missing_shows.join(', ')
    puts "#{invalid_items.size} invalid recs:\n" + invalid_items.join("\n")
  end

  def find_song_by_title(title)
    songs.find { |s| s.title.casecmp(title).zero? }
  end

  def handle_item(item, show)
    track_matched = false
    show.tracks.sort_by(&:position).each do |track|
      song = find_song_by_title(item['song'])
      next if song.nil?

      st = SongsTrack.where(song_id: song.id, track_id: track.id).first
      next if st.nil?
      track_matched = true

      tt = TrackTag.find_by(track: track, tag: jamcharts_tag)
      next if tt&.notes == item['jamchart_description']

      # TODO: Handle multiple jamcharts descriptions for the same track
      # (is this an error on phish.net side?  Shouldn't these be unique?)
      details = "#{show.date} => #{track.title} (#{track.id})"
      if tt.present?
        puts "Updating #{details}"
        tt.update(notes: item['jamchart_description'])
      else
        puts "Creating #{details}"
        TrackTag.create!(
          track: track,
          tag: jamcharts_tag,
          notes: item['jamchart_description']
        )
      end

      @invalid_items << "#{item['showdate']} - #{item['song']}" unless track_matched
    end
  end
end
