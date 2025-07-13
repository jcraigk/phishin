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

    previous_performance = find_previous_performance_locally
    return [] unless previous_performance

    # Get shows between previous performance and current show
    start_date = previous_performance.show.date
    end_date = @show.date

    # Fetch ALL PhishNet shows and filter properly
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
    # Keep multiple shows per date as separate entries - don't deduplicate
    pnet_shows_in_gap = pnet_shows.select do |pnet_show|
      show_date = Date.parse(pnet_show["showdate"])
      show_date > start_date && show_date < end_date
    end

    # Get our local shows for the same date range
    local_shows_in_gap = Show.where(date: start_date.next_day..end_date.prev_day)
                             .where(exclude_from_stats: false)
                             .order(:date)

    # Build detailed comparison data
    comparison_data = build_show_comparison(pnet_shows_in_gap, local_shows_in_gap)

    {
      source: "PHISHNET API",
      previous_performance: {
        date: previous_performance.show.date.to_s,
        venue: previous_performance.show.venue_name,
        track_title: previous_performance.title,
        position: previous_performance.position
      },
      shows_in_gap: comparison_data[:shows],
      gap_calculation: "#{pnet_shows_in_gap.count} shows + 1 = #{pnet_shows_in_gap.count + 1}",
      total_shows_in_gap: pnet_shows_in_gap.count,
      note: "Shows filtered by exclude_from_stats=1, multiple shows per date preserved",
      comparison_summary: comparison_data[:summary]
    }
  end

  def build_show_comparison(pnet_shows_in_gap, local_shows_in_gap)
    # Group shows by date for comparison
    pnet_by_date = pnet_shows_in_gap.group_by { |show| show["showdate"] }
    local_by_date = local_shows_in_gap.group_by { |show| show.date.to_s }

    # Get all unique dates in the gap range
    all_dates = (pnet_by_date.keys + local_by_date.keys).uniq.sort

    shows = []
    summary = {
      total_dates: all_dates.count,
      dates_with_mismatched_counts: 0,
      total_pnet_shows: pnet_shows_in_gap.count,
      total_local_shows: local_shows_in_gap.count,
      dates_only_in_pnet: [],
      dates_only_in_local: [],
      dates_with_count_mismatch: []
    }

    all_dates.each do |date|
      pnet_shows_for_date = pnet_by_date[date] || []
      local_shows_for_date = local_by_date[date] || []

      pnet_count = pnet_shows_for_date.count
      local_count = local_shows_for_date.count

      # Track mismatches
      if pnet_count != local_count
        summary[:dates_with_mismatched_counts] += 1
        summary[:dates_with_count_mismatch] << {
          date: date,
          pnet_count: pnet_count,
          local_count: local_count,
          difference: local_count - pnet_count
        }
      end

      if pnet_count > 0 && local_count == 0
        summary[:dates_only_in_pnet] << date
      elsif local_count > 0 && pnet_count == 0
        summary[:dates_only_in_local] << date
      end

      # Add individual show entries for detailed analysis
      max_count = [ pnet_count, local_count ].max
      (0...max_count).each do |index|
        pnet_show = pnet_shows_for_date[index]
        local_show = local_shows_for_date[index]

        shows << {
          date: date,
          show_index: index + 1,
          total_shows_for_date: { pnet: pnet_count, local: local_count },
          pnet_data: pnet_show ? {
            venue: pnet_show["venue"] || "Unknown Venue",
            showid: pnet_show["showid"],
            exclude_from_stats: pnet_show["exclude_from_stats"] == 1
          } : nil,
          local_data: local_show ? {
            venue: local_show.venue_name,
            audio_status: local_show.audio_status,
            exclude_from_stats: local_show.exclude_from_stats
          } : nil,
          match_status: determine_match_status(pnet_show, local_show)
        }
      end
    end

    { shows: shows, summary: summary }
  end

  def determine_match_status(pnet_show, local_show)
    if pnet_show && local_show
      "both_present"
    elsif pnet_show && !local_show
      "only_in_pnet"
    elsif !pnet_show && local_show
      "only_in_local"
    else
      "neither_present" # shouldn't happen
    end
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
    summary = remote_shows[:comparison_summary]

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
    analysis << "=== DETAILED COMPARISON ==="
    analysis << "Total dates in gap range: #{summary[:total_dates]}"
    analysis << "Dates with mismatched show counts: #{summary[:dates_with_mismatched_counts]}"
    analysis << ""

    # Show dates that only exist in one system
    if summary[:dates_only_in_pnet].any?
      analysis << "📅 Dates only in PhishNet (#{summary[:dates_only_in_pnet].count}):"
      summary[:dates_only_in_pnet].each do |date|
        pnet_shows = remote_shows[:shows_in_gap].select { |s| s[:date] == date }
        pnet_shows.each do |show|
          analysis << "  • #{date} - #{show[:pnet_data][:venue]} [showid: #{show[:pnet_data][:showid]}]"
        end
      end
      analysis << ""
    end

    if summary[:dates_only_in_local].any?
      analysis << "📅 Dates only in Local DB (#{summary[:dates_only_in_local].count}):"
      summary[:dates_only_in_local].each do |date|
        local_shows_for_date = remote_shows[:shows_in_gap].select { |s| s[:date] == date }
        local_shows_for_date.each do |show|
          analysis << "  • #{date} - #{show[:local_data][:venue]} (#{show[:local_data][:audio_status]})"
        end
      end
      analysis << ""
    end

    # Show dates with different show counts
    if summary[:dates_with_count_mismatch].any?
      analysis << "🔢 Dates with different show counts (#{summary[:dates_with_count_mismatch].count}):"
      summary[:dates_with_count_mismatch].each do |mismatch|
        analysis << "  • #{mismatch[:date]}: PhishNet=#{mismatch[:pnet_count]}, Local=#{mismatch[:local_count]} (diff: #{mismatch[:difference] > 0 ? '+' : ''}#{mismatch[:difference]})"

        # Show details for this date
        shows_for_date = remote_shows[:shows_in_gap].select { |s| s[:date] == mismatch[:date] }
        shows_for_date.each do |show|
          case show[:match_status]
          when "both_present"
            analysis << "    ✅ #{show[:pnet_data][:venue]} (both systems)"
          when "only_in_pnet"
            analysis << "    📍 #{show[:pnet_data][:venue]} (PhishNet only) [showid: #{show[:pnet_data][:showid]}]"
          when "only_in_local"
            analysis << "    🏠 #{show[:local_data][:venue]} (Local only, #{show[:local_data][:audio_status]})"
          end
        end
      end
      analysis << ""
    end

    analysis << "🎵 Previous performance comparison:"
    analysis << "  Local:  #{local_shows[:previous_performance][:date]} - #{local_shows[:previous_performance][:venue]}"
    analysis << "  Remote: #{remote_shows[:previous_performance][:date]} - #{remote_shows[:previous_performance][:venue]}"
    analysis << ""

    # Summary insights
    analysis << "🔍 KEY INSIGHTS:"
    if summary[:dates_with_mismatched_counts] == 0 && summary[:dates_only_in_pnet].empty? && summary[:dates_only_in_local].empty?
      analysis << "  ✅ All dates match perfectly between systems"
      analysis << "  ❓ Gap discrepancy may be due to different +1 calculation logic"
    else
      analysis << "  📊 Show count differences found - this explains the gap discrepancy"
      if summary[:dates_only_in_local].any?
        analysis << "  🏠 Local database includes dates that PhishNet excludes"
      end
      if summary[:dates_only_in_pnet].any?
        analysis << "  📍 PhishNet includes dates that local database excludes"
      end
      if summary[:dates_with_count_mismatch].any?
        analysis << "  🔢 Some dates have different numbers of shows between systems"
      end
    end

    analysis
  end
end
