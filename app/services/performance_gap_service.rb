class PerformanceGapService < ApplicationService
  BASE_URL = "https://api.phish.net/v5".freeze

  param :show

  def call
    return unless api_key

    populate_gaps_from_phishnet
  end

  private

        def populate_gaps_from_phishnet
    log_info "Processing show #{show.date}"

    setlist_data = fetch_phishnet_setlist
    if setlist_data.empty?
      log_info "❌ No setlist data found for show #{show.date}"
      return
    end

    log_info "Found #{setlist_data.length} setlist items from Phish.net"

    # Track which songs we've seen in this show to handle duplicates
    seen_songs = Set.new

    # Get all songs_tracks for the show ordered by track position
    songs_tracks = SongsTrack.joins(:track, :song)
                             .where(tracks: { show: show })
                             .where.not(tracks: { set: "S" }) # Exclude soundcheck
                             .order("tracks.position")

    log_info "Found #{songs_tracks.length} songs_tracks for show #{show.date} (excluding soundcheck)"

    # Track which songs_tracks have been matched to avoid double-matching
    matched_songs_track_ids = Set.new

    # Match each setlist item to songs_tracks by song title
    setlist_data.each_with_index do |item, index|
      next unless item["song"] # Skip items without song data

      # Find matching songs_track by song title
      songs_track = find_matching_songs_track(item, songs_tracks, matched_songs_track_ids)

      unless songs_track
        log_info "❌ No matching songs_track found for '#{item['song']}'"
        next
      end

      song = songs_track.song

      # Determine the gap for this performance
      gap = if seen_songs.include?(song.id)
              0 # Later instances of the same song in the same show have gap 0
      else
              item["gap"] # First instance gets the gap from Phish.net (could be nil for debuts)
      end

      # Update previous performance gap for current show
      songs_track.update!(previous_performance_gap: gap)
      log_info "💾 Updated songs_track #{songs_track.id} (#{song.title}) with previous_performance_gap: #{gap.inspect}"

      # Update next performance gap on the most recent earlier performance
      # Only update if gap is not nil and not 0
      if gap && gap > 0
        update_next_performance_gap(song, gap)
      else
        log_info "⏭️ Skipping next_performance_gap update for '#{song.title}' (gap: #{gap.inspect})"
      end

      # Mark this song as seen in this show
      seen_songs.add(song.id)
      # Mark this songs_track as matched
      matched_songs_track_ids.add(songs_track.id)
    end

    # Check for any unmatched songs_tracks
    unmatched_songs_tracks = songs_tracks.reject { |st| matched_songs_track_ids.include?(st.id) }
    if unmatched_songs_tracks.any?
      log_info "❌ #{unmatched_songs_tracks.length} songs_tracks were not matched:"
      unmatched_songs_tracks.each do |st|
        log_info "  - Track #{st.track.position}: '#{st.song.title}' (songs_track #{st.id})"
        # Set previous_performance_gap to nil for unmatched tracks
        st.update!(previous_performance_gap: nil)
        log_info "💾 Set previous_performance_gap to nil for unmatched '#{st.song.title}'"
      end
    else
      log_info "✅ All songs_tracks were successfully matched"
    end

    log_info "✅ Completed processing show #{show.date}"
  end

  def find_matching_songs_track(setlist_item, songs_tracks, matched_songs_track_ids)
    song_title = setlist_item["song"].downcase.strip

    # Find songs_tracks that match this song title and haven't been matched yet
    candidates = songs_tracks.select do |st|
      st.song.title.downcase.strip == song_title && !matched_songs_track_ids.include?(st.id)
    end

    # If we have multiple candidates (song appears multiple times),
    # pick the first unmatched one in track order
    candidates.first
  end

      def update_next_performance_gap(song, gap)
    # Find the most recent show before this one that has this song
    previous_performance = find_most_recent_previous_performance(song)

    unless previous_performance
      log_info "❌ No previous performance found for '#{song.title}'"
      return
    end

    # Update the next_performance_gap for that earlier performance
    previous_performance.update!(next_performance_gap: gap)
    log_info "💾 Updated previous performance of '#{song.title}' (songs_track #{previous_performance.id}) with next_performance_gap: #{gap}"
  end

  def find_most_recent_previous_performance(song)
    # Find the most recent songs_track record for this song before the current show
    SongsTrack.joins(track: :show)
               .where(song: song)
               .where("shows.date < ?", show.date)
               .where.not(tracks: { set: "S" }) # Exclude soundcheck
               .order("shows.date DESC, tracks.position DESC")
               .first
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

  def api_key
    ENV.fetch("PNET_API_KEY", nil)
  end

  def phishnet_api_url
    "#{BASE_URL}/setlists/showdate/#{show.date}.json?apikey=#{api_key}"
  end

  def log_info(message)
    Rails.logger.info(message) unless Rails.env.test?
  end
end
