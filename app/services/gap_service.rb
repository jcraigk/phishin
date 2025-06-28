class GapService < ApplicationService
  BASE_URL = "https://api.phish.net/v5".freeze

  param :show

  def call
    return unless api_key

    populate_gaps_from_phishnet
  end

  private

  def populate_gaps_from_phishnet
    setlist_data = fetch_phishnet_setlist
    return if setlist_data.empty?

    setlist_data.each do |item|
      next unless item["gap"] # Skip items without gap data

      # Find the corresponding track and song
      track = find_matching_track(item)
      next unless track

      song = Song.find_by(title: item["song"])
      next unless song

      songs_track = SongsTrack.find_by(track: track, song: song)
      next unless songs_track

      # Update the gap data from Phish.net
      update_gap_data(songs_track, item, setlist_data)
    end
  end

  def fetch_phishnet_setlist
    response = Typhoeus.get(phishnet_api_url)
    return [] unless response.success?

    data = JSON.parse(response.body)
    return [] if data["error"] || data["data"].empty?

    data["data"]
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error "Failed to fetch Phish.net setlist for #{show.date}: #{e.message}"
    []
  end

  def find_matching_track(setlist_item)
    # Map Phish.net set notation to local notation
    # Phish.net uses: 1, 2, E (encore), S (soundcheck)
    # Local uses: 1, 2, 3 (encore), S (soundcheck)
    set_mapping = { "E" => "3" }
    mapped_set = set_mapping[setlist_item["set"]] || setlist_item["set"]

    show.tracks.find_by(
      position: setlist_item["position"],
      set: mapped_set
    )
  end

  def update_gap_data(songs_track, current_item, all_setlist_data)
    gap = current_item["gap"]

    # Update previous performance gap (this is the main gap data from Phish.net)
    songs_track.update!(previous_performance_gap: gap)

    # Note: next_performance_gap will be calculated in a separate pass
    # after all shows have their previous gaps populated
  end

  def api_key
    ENV.fetch("PNET_API_KEY", nil)
  end

  def phishnet_api_url
    "#{BASE_URL}/setlists/showdate/#{show.date}.json?apikey=#{api_key}"
  end
end
