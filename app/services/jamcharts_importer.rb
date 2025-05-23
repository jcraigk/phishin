class JamchartsImporter < ApplicationService
  include ActionView::Helpers::SanitizeHelper

  BASE_URL = "https://api.phish.net/v5".freeze
  API_KEY = ENV.fetch("PNET_API_KEY", nil)

  attr_reader :invalid_items, :missing_shows, :matched_ids

  param :api_key

  def call
    @invalid_items = []
    @missing_shows = []
    @matched_ids = []

    sync_jamcharts
  end

  private

  def jamcharts_tag
    @jamcharts_tag ||= Tag.where(name: "Jamcharts").first
  end

  def phishnet_uri
    URI.parse("#{BASE_URL}/jamcharts.json?apikey=#{API_KEY}")
  end

  def songs
    @songs ||= Song.all
  end

  def jamcharts_as_json
    @jamcharts_as_json ||= JSON[Net::HTTP.get_response(phishnet_uri).body]["data"]
  end

  def create_progress_bar
    ProgressBar.create(total: jamcharts_as_json.size, format: "%a %B %c/%C %p%% %E")
  end

  def find_show_by_date(date)
    Show.includes(:tracks).find_by(date:)
  end

  def sync_jamcharts
    pbar = create_progress_bar

    jamcharts_as_json.each do |item|
      show = find_show_by_date(item["showdate"])
      next @missing_shows << item["showdate"] unless show
      handle_item(item, show)
      pbar.increment
    end

    pbar.finish
    print_results
  end

  def print_results
    puts "#{missing_shows.size} missing shows:\n" + missing_shows.join(", ")
    # puts "#{invalid_items.size} invalid recs:\n" + invalid_items.join("\n")
  end

  def find_song_by_title(title)
    songs.find { |s| s.title.casecmp(title).zero? }
  end

  def sanitize_str(str)
    return if str.nil?
    sanitize(str.gsub(/[”“]/, '"').gsub(/[‘’]/, "'").strip)
  end

  def handle_item(item, show) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    song = find_song_by_title(item["song"])
    return if handle_ambiguous_item(item)

    show.tracks.where.not(set: "S").order(:position).each do |track|
      next if song.nil?

      st = SongsTrack.where(song_id: song.id, track_id: track.id).first
      next if st.nil?

      next if matched_ids.include?(track.id) # Skip to next occurrence of song in set
      matched_ids << track.id

      desc = sanitize_str(item["jamchart_description"])

      return create_or_update_tag(track, desc)
    end

    @invalid_items << "#{item['showdate']} - #{item['song']}"
  end

  def create_or_update_tag(track, desc)
    notes = html_entities_coder.decode(desc)
    TrackTag.find_or_initialize_by(track:, tag: jamcharts_tag).update!(notes:)
  end

  # Ambiguous: show contains multiple tracks of a song, only one is jamcharted
  def handle_ambiguous_item(item)
    return unless (matched_item = ambiguous_item(item))
    track = Track.find(matched_item[:track_id])
    create_or_update_tag(track, sanitize_str(item["jamchart_description"]))
    true
  end

  def ambiguous_item(item)
    ambiguous_items.find { |i| i[:showid] == item["showid"].to_s && i[:song] == item["song"] }
  end
2
  def ambiguous_items
    [
      {
        song: "Wipe Out",
        showid: "1252806821",
        track_id: "18941"
      }
    ]
  end

  def html_entities_coder
    @html_entities_coder ||= HTMLEntities.new
  end
end
