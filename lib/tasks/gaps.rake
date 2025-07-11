namespace :gaps do
  desc "Reset and rebuild all performance gap data from scratch"
  task rebuild: :environment do
    puts "🔄 Starting complete rebuild of all performance gap data..."
    puts "This will reset all gap/slug data and rebuild from scratch."
    print "Continue? (y/N): "
    exit unless STDIN.gets.chomp.downcase == "y"

    puts "📊 Step 1: Resetting all performance gap and slug fields to nil..."
    SongsTrack.update_all(
      previous_performance_gap: nil,
      previous_performance_slug: nil,
      next_performance_gap: nil,
      next_performance_slug: nil,
      previous_performance_gap_with_audio: nil,
      previous_performance_slug_with_audio: nil,
      next_performance_gap_with_audio: nil,
      next_performance_slug_with_audio: nil
    )

    puts "📊 Step 2: Processing all shows with tracks chronologically..."
    shows = Show.joins(:tracks)
                .where.not(tracks: { set: "S" })
                .where(exclude_from_stats: false)
                .distinct
                .order(:date)

    processed = 0

    pbar = ProgressBar.create(
      title: "Processing",
      total: shows.count,
      format: "%a %B %c/%C %p%% %E"
    )

    shows.each do |show|
      begin
        GapService.call(show)
        processed += 1
        pbar.increment
      rescue StandardError => e
        puts "\nError processing show #{show.date}: #{e.message}"
        pbar.increment
      end

      sleep(0.01) if processed % 50 == 0
    end

    pbar.finish
    puts "✅ Completed processing #{processed} shows"
  end

  desc "Recalculate gaps for a specific show"
  task :recalculate, [:date] => :environment do |t, args|
    unless args[:date]
      puts "Usage: rake gaps:recalculate[YYYY-MM-DD]"
      exit 1
    end

    show = Show.find_by(date: args[:date])
    unless show
      puts "Show not found for date: #{args[:date]}"
      exit 1
    end

    puts "🔄 Recalculating gaps for show #{show.date}..."
    GapService.call(show, update_previous: true)
    puts "✅ Completed gap recalculation for #{show.date}"
  end

  desc "Spot check local gaps against PhishNet API data"
  task :spot_check_phishnet, [:limit] => :environment do |t, args|
    limit = args[:limit]&.to_i || ENV["LIMIT"]&.to_i || 10

    puts "🔍 Starting spot check of local gaps against PhishNet API..."
    puts "Checking #{limit} random shows that count for stats..."

    # Get random sample of shows that count for stats and have tracks
    show_ids = Show.joins(:tracks)
                   .where.not(tracks: { set: "S" })
                   .where(exclude_from_stats: false)
                   .where.not(audio_status: "missing")
                   .distinct
                   .pluck(:id)
                   .sample(limit)

    shows = Show.where(id: show_ids)

    total_comparisons = 0
    matches = 0
    mismatches = 0
    errors = 0

    puts "\n" + "="*80

    shows.each_with_index do |show, idx|
      puts "\n[#{idx + 1}/#{limit}] Checking show: #{show.date}"

      begin
        # Fetch setlist data from PhishNet
        response = Typhoeus.get(
          "https://api.phish.net/v5/setlists/showdate/#{show.date.strftime('%Y-%m-%d')}.json",
          params: { apikey: ENV.fetch("PNET_API_KEY", nil) }
        )

        unless response.success?
          puts "  ❌ Error fetching PhishNet data: HTTP #{response.code}"
          errors += 1
          next
        end

        data = JSON.parse(response.body)
        unless data["data"] && data["data"].any?
          puts "  ⚠️  No setlist data available on PhishNet"
          next
        end

        # Filter to only include Phish tracks (exclude guest appearances)
        pnet_setlist = data["data"].select { |song_data| song_data["artist_slug"] == "phish" }
        local_tracks = show.tracks.includes(:songs, :songs_tracks).where.not(set: "S").order(:position)

        puts "  📊 Comparing #{pnet_setlist.length} PhishNet tracks vs #{local_tracks.length} local tracks"

        track_matches = 0
        track_mismatches = 0

        # Compare each track's gap data
        pnet_setlist.each_with_index do |pnet_song, idx|
          local_track = local_tracks[idx]
          next unless local_track

          # Try to find matching song by title
          pnet_song_title = pnet_song["song"]&.downcase&.strip
          local_song = local_track.songs.find { |s| s.title.downcase.strip == pnet_song_title }

          next unless local_song

          songs_track = local_track.songs_tracks.find { |st| st.song_id == local_song.id }
          next unless songs_track

          local_gap = songs_track.previous_performance_gap

          # PhishNet API v5 uses "gap" field for previous performance gap
          pnet_gap = pnet_song["gap"]

          total_comparisons += 1

          if pnet_gap.nil?
            puts "    ⚠️  No gap data in PhishNet for: #{pnet_song_title}"
            next
          end

          # Handle special gap comparison logic:
          # 1. If PhishNet gap is 0, we expect local to be nil (consecutive shows)
          # 2. If local is nil (first occurrence), PhishNet shows total shows up to that point
          # 3. If local is 0 and PhishNet is 1, likely same-show occurrence
          gap_matches = false
          match_reason = ""

          if pnet_gap == 0 && local_gap.nil?
            gap_matches = true
            match_reason = " (PhishNet 0 = local nil)"
          elsif local_gap.nil? && pnet_gap > 0
            gap_matches = true
            match_reason = " (first occurrence: local nil, PhishNet shows total)"
          elsif local_gap == 0 && pnet_gap == 1
            gap_matches = true
            match_reason = " (same-show occurrence: local 0, PhishNet 1)"
          elsif local_gap == pnet_gap
            gap_matches = true
            match_reason = " (exact match)"
          end

          if gap_matches
            track_matches += 1
            puts "    ✅ #{pnet_song_title}: Local=#{local_gap}, PhishNet=#{pnet_gap}#{match_reason}"
          else
            track_mismatches += 1
            puts "    ❌ #{pnet_song_title}: Local=#{local_gap}, PhishNet=#{pnet_gap} (MISMATCH)"
          end
        end

        matches += track_matches
        mismatches += track_mismatches

        puts "  📈 Show summary: #{track_matches} matches, #{track_mismatches} mismatches"

      rescue StandardError => e
        puts "  ❌ Error processing show #{show.date}: #{e.message}"
        errors += 1
      end

      # Rate limiting - be nice to PhishNet API
      sleep(1) if idx < shows.count - 1
    end

    puts "\n" + "="*80
    puts "🏁 FINAL RESULTS:"
    puts "   Total comparisons: #{total_comparisons}"
    puts "   ✅ Matches: #{matches}"
    puts "   ❌ Mismatches: #{mismatches}"
    puts "   ⚠️  Errors: #{errors}"

    if total_comparisons > 0
      accuracy = (matches.to_f / total_comparisons * 100).round(2)
      puts "   📊 Accuracy: #{accuracy}%"

      if accuracy < 95
        puts "\n⚠️  Accuracy below 95% - consider running gap rebuild"
        puts "   Run: rake gaps:rebuild"
      else
        puts "\n✅ Gap data appears to be accurate!"
      end
    end

    if mismatches > 0
      puts "\n🔧 To fix specific mismatches, you can:"
      puts "   1. Run gap rebuild: rake gaps:rebuild"
      puts "   2. Recalculate specific shows: rake gaps:recalculate[YYYY-MM-DD]"
      puts "   3. Check if shows are properly marked as exclude_from_stats"
    end

    puts "\n📝 NOTE: This task assumes PhishNet API includes gap data in setlist responses."
    puts "   If you see many 'No gap data' warnings, the API field name may need adjustment."
    puts "   Check the PhishNet API documentation for the correct gap field name."
  end

  desc "Check gap data integrity for a specific show"
  task :check_show, [:date] => :environment do |t, args|
    unless args[:date]
      puts "Usage: rake gaps:check_show[YYYY-MM-DD]"
      exit 1
    end

    show = Show.find_by(date: args[:date])
    unless show
      puts "Show not found for date: #{args[:date]}"
      exit 1
    end

    puts "🔍 Checking gap data integrity for show #{show.date}"
    puts "Show details:"
    puts "  Venue: #{show.venue_name}"
    puts "  Audio Status: #{show.audio_status}"
    puts "  Exclude from Stats: #{show.exclude_from_stats}"
    puts "  Track Count: #{show.tracks.count}"

    tracks_with_gaps = show.tracks.joins(:songs_tracks)
                           .where.not(set: "S")
                           .includes(:songs, :songs_tracks)

    puts "\nGap data for non-soundcheck tracks:"
    puts "-" * 60

    tracks_with_gaps.each do |track|
      puts "#{track.position}. #{track.title} (Set #{track.set})"

      track.songs_tracks.each do |st|
        song = st.song
        puts "    Song: #{song.title}"
        puts "      Previous gap: #{st.previous_performance_gap || 'nil'}"
        puts "      Previous slug: #{st.previous_performance_slug || 'nil'}"
        puts "      Next gap: #{st.next_performance_gap || 'nil'}"
        puts "      Next slug: #{st.next_performance_slug || 'nil'}"
        puts "      Previous gap (w/ audio): #{st.previous_performance_gap_with_audio || 'nil'}"
        puts "      Next gap (w/ audio): #{st.next_performance_gap_with_audio || 'nil'}"
      end
      puts
    end
  end
end
