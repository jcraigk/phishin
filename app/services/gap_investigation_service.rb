class GapInvestigationService < ApplicationService
  param :show_date
  param :track_title

  def call
    @show = Show.find_by(date: show_date)
    return { error: "Show not found for date: #{show_date}" } unless @show

    @track = find_track_by_title(track_title)
    return { error: "Track '#{track_title}' not found in show #{show_date}" } unless @track

    @song = @track.songs.first
    return { error: "No song associated with track '#{track_title}'" } unless @song

    @songs_track = SongsTrack.find_by(track: @track, song: @song)
    return { error: "No songs_track record found" } unless @songs_track

    # Get local and remote gap data
    local_gap = @songs_track.previous_performance_gap
    remote_gap = fetch_remote_gap

    return { error: "Could not fetch remote gap data" } if remote_gap.nil?

    if local_gap == remote_gap
      return {
        message: "Gaps match - no discrepancy found",
        local_gap: local_gap,
        remote_gap: remote_gap
      }
    end

    # Gaps differ - investigate
    local_shows = get_local_gap_shows
    remote_shows = get_remote_gap_shows

    {
      message: "Gap discrepancy found",
      local_gap: local_gap,
      remote_gap: remote_gap,
      local_shows: local_shows,
      remote_shows: remote_shows,
      analysis: analyze_discrepancy(local_shows, remote_shows)
    }
  end

  private

  def find_track_by_title(title)
    # Try exact match first
    track = @show.tracks.where("lower(title) = ?", title.downcase).first
    return track if track

    # Try fuzzy match
    @show.tracks.where("lower(title) LIKE ?", "%#{title.downcase}%").first
  end

    def fetch_remote_gap
    # Get the remote gap by fetching setlist data directly from PhishNet API
    # This matches the approach used in the spot check task
    response = Typhoeus.get(
      "https://api.phish.net/v5/setlists/showdate/#{@show.date.strftime('%Y-%m-%d')}.json",
      params: { apikey: ENV.fetch("PNET_API_KEY", nil) }
    )

    return nil unless response.success?

    data = JSON.parse(response.body)
    return nil unless data["data"] && data["data"].any?

    # Filter to only include Phish tracks (exclude guest appearances)
    pnet_setlist = data["data"].select { |song_data| song_data["artist_slug"] == "phish" }

    # Find the matching song in the PhishNet setlist
    song_title = @song.title.downcase.strip
    pnet_song = pnet_setlist.find { |song| song["song"]&.downcase&.strip == song_title }

    return nil unless pnet_song

    # Return the gap value from PhishNet
    pnet_song["gap"]
  rescue StandardError
    nil
  end

  def get_local_gap_shows
    return [] unless @songs_track.previous_performance_gap

    previous_performance = find_previous_performance_locally
    return [] unless previous_performance

    # Get shows between previous performance and current show
    start_date = previous_performance.show.date
    end_date = @show.date

    shows_in_gap = Show.where(date: start_date.next_day..end_date.prev_day)
                       .where(exclude_from_stats: false)
                       .order(:date)

    {
      source: "LOCAL DATABASE",
      previous_performance: {
        date: previous_performance.show.date,
        venue: previous_performance.show.venue_name,
        track_title: previous_performance.title,
        position: previous_performance.position
      },
      shows_in_gap: shows_in_gap.map do |show|
        {
          date: show.date,
          venue: show.venue_name,
          exclude_from_stats: show.exclude_from_stats,
          audio_status: show.audio_status
        }
      end,
      gap_calculation: "#{shows_in_gap.count} shows + 1 = #{shows_in_gap.count + 1}",
      total_shows_in_gap: shows_in_gap.count
    }
  end

  def get_remote_gap_shows
    return [] unless @songs_track.previous_performance_gap

    previous_performance = find_previous_performance_remotely
    return [] unless previous_performance

    # Get shows between previous performance and current show from PhishNet perspective
    start_date = Date.parse(previous_performance[:date])
    end_date = @show.date

    # Get PhishNet show data directly from API
    response = Typhoeus.get(
      "https://api.phish.net/v5/shows/artist/phish.json",
      params: {
        apikey: ENV.fetch("PNET_API_KEY", nil),
        order_by: "showdate"
      }
    )

    unless response.success?
      puts "Error fetching PhishNet data: HTTP #{response.code}"
      return { error: "Failed to fetch PhishNet data" }
    end

    data = JSON.parse(response.body)
    all_pnet_shows = data["data"] || []

    # Filter out shows with exclude_from_stats = 1 (same as PhishNet does for gap calculations)
    pnet_shows = all_pnet_shows.reject { |show| show["exclude_from_stats"] == 1 }

    # Filter PhishNet shows to only those in our gap range
    # Note: exclude_from_stats filtering already done in cache, but keeping check for safety
    # Also, we don't make dates unique - multiple shows on same date count separately
    pnet_shows_in_gap = pnet_shows.select do |pnet_show|
      show_date = Date.parse(pnet_show["showdate"])
      show_date > start_date && show_date < end_date
    end

    # Also get our local shows for comparison
    local_shows_in_gap = Show.where(date: start_date.next_day..end_date.prev_day)
                             .where(exclude_from_stats: false)
                             .order(:date)

    {
      source: "PHISHNET API",
      previous_performance: previous_performance,
      shows_in_gap: pnet_shows_in_gap.map do |pnet_show|
        local_show = local_shows_in_gap.find { |s| s.date.to_s == pnet_show["showdate"] }
        {
          date: pnet_show["showdate"],
          venue: pnet_show["venue"] || "Unknown Venue",
          exclude_from_stats: pnet_show["exclude_from_stats"] == 1,
          audio_status: local_show&.audio_status || "unknown",
          in_local_db: !local_show.nil?
        }
      end,
      gap_calculation: "#{pnet_shows_in_gap.count} shows + 1 = #{pnet_shows_in_gap.count + 1}",
      total_shows_in_gap: pnet_shows_in_gap.count,
      note: "Shows already filtered by exclude_from_stats=1 from API"
    }
  end

  def find_previous_performance_locally
    # Use the same logic as GapService
    previous_tracks = Track.joins(:show, :songs)
                           .where(songs: { id: @song.id })
                           .where("tracks.set <> ?", "S")
                           .where("shows.date < ?", @track.show.date)
                           .where(shows: { exclude_from_stats: false })
                           .order("shows.date DESC, tracks.position DESC")

    previous_tracks_within_show = @track.show
                                        .tracks
                                        .joins(:songs)
                                        .where(songs: { id: @song.id })
                                        .where("tracks.set <> ?", "S")
                                        .where("tracks.position < ?", @track.position)
                                        .order("tracks.position DESC")

    return previous_tracks_within_show.first if previous_tracks_within_show.exists?

    previous_tracks.first
  end

    def find_previous_performance_remotely
    # For now, use local data but add more detailed analysis
    # The key insight is that PhishNet might be excluding certain shows
    # that we're including, or using different counting logic
    previous_performance = find_previous_performance_locally
    return nil unless previous_performance

    {
      date: previous_performance.show.date.to_s,
      venue: previous_performance.show.venue_name,
      track_title: previous_performance.title,
      position: previous_performance.position,
      note: "Using local data - PhishNet may exclude some shows we include"
    }
  end

  def analyze_discrepancy(local_shows, remote_shows)
    analysis = []

    if local_shows.empty? || remote_shows.empty?
      analysis << "Unable to analyze - missing show data"
      return analysis
    end

    local_count = local_shows[:total_shows_in_gap]
    remote_count = remote_shows[:total_shows_in_gap]

    analysis << "=== GAP ANALYSIS ==="
    analysis << "Local database gap: #{local_count} shows (#{local_shows[:source]})"
    analysis << "Remote PhishNet gap: #{remote_count} shows (#{remote_shows[:source]})"
    analysis << ""

    if local_count > remote_count
      analysis << "❌ DISCREPANCY: Local has #{local_count - remote_count} more shows in gap than remote"
    elsif remote_count > local_count
      analysis << "❌ DISCREPANCY: Remote has #{remote_count - local_count} more shows in gap than local"
    else
      analysis << "✅ Show counts match between local and remote"
    end

    analysis << ""

    # Compare show lists to find discrepancies
    local_dates = local_shows[:shows_in_gap].map { |s| s[:date].to_s }.sort
    remote_dates = remote_shows[:shows_in_gap].map { |s| s[:date].to_s }.sort

    # Get unique dates for comparison
    local_unique_dates = local_dates.uniq
    remote_unique_dates = remote_dates.uniq

    only_in_local = local_unique_dates - remote_unique_dates
    only_in_remote = remote_unique_dates - local_unique_dates

    if only_in_local.any?
      analysis << "📅 Shows only in LOCAL gap (#{only_in_local.count}):"
      only_in_local.each do |date|
        local_show = local_shows[:shows_in_gap].find { |s| s[:date].to_s == date }
        analysis << "  • #{date} - #{local_show[:venue]} (#{local_show[:audio_status]})"
      end
      analysis << ""
    end

    if only_in_remote.any?
      analysis << "📅 Shows only in REMOTE gap (#{only_in_remote.count}):"
      only_in_remote.each do |date|
        remote_show = remote_shows[:shows_in_gap].find { |s| s[:date].to_s == date }
        analysis << "  • #{date} - #{remote_show[:venue]}"
      end
      analysis << ""
    end

    # Check for multiple shows per date differences
    local_date_counts = local_dates.group_by(&:itself).transform_values(&:count)
    remote_date_counts = remote_dates.group_by(&:itself).transform_values(&:count)

    date_count_diffs = []
    (local_unique_dates + remote_unique_dates).uniq.each do |date|
      local_count = local_date_counts[date] || 0
      remote_count = remote_date_counts[date] || 0
      if local_count != remote_count
        date_count_diffs << "#{date}: Local=#{local_count}, Remote=#{remote_count}"
      end
    end

    if date_count_diffs.any?
      analysis << "🔢 Different show counts per date:"
      date_count_diffs.each { |diff| analysis << "  • #{diff}" }
      analysis << ""
    end

    # Check for shows missing from local database
    remote_shows_not_in_local = remote_shows[:shows_in_gap].select { |s| !s[:in_local_db] }
    if remote_shows_not_in_local.any?
      missing_dates = remote_shows_not_in_local.map { |s| s[:date] }
      analysis << "⚠️  Shows in PhishNet but missing from local database: #{missing_dates.join(', ')}"
      analysis << ""
    end

    analysis << "🎵 Previous performance comparison:"
    analysis << "  Local:  #{local_shows[:previous_performance][:date]} - #{local_shows[:previous_performance][:venue]}"
    analysis << "  Remote: #{remote_shows[:previous_performance][:date]} - #{remote_shows[:previous_performance][:venue]}"

    analysis
  end
end
