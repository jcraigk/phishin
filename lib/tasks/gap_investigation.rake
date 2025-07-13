namespace :gaps do
  desc "Investigate gap discrepancy for a specific track"
  task :investigate, [ :date, :track_title ] => :environment do |t, args|
    unless args[:date] && args[:track_title]
      puts "Usage: rake gaps:investigate[YYYY-MM-DD,'Track Title']"
      puts "Example: rake gaps:investigate[2003-02-18,'The Moma Dance']"
      exit 1
    end

    date = args[:date]
    track_title = args[:track_title]

    puts "🔍 Investigating gap discrepancy for '#{track_title}' on #{date}"
    puts "=" * 80

    result = GapInvestigationService.call(date, track_title)

    if result[:error]
      puts "❌ Error: #{result[:error]}"
      exit 1
    end

    data = result

    puts "📊 GAP COMPARISON:"
    puts "   Local Gap:  #{data[:local_gap]}"
    puts "   Remote Gap: #{data[:remote_gap]}"
    puts "   Status:     #{data[:message]}"
    puts

    if data[:message] == "Gaps match - no discrepancy found"
      puts "✅ No discrepancy found - gaps match!"
      exit 0
    end

    # Display detailed analysis
    puts "🔍 DETAILED ANALYSIS:"
    data[:analysis].each do |analysis_point|
      puts "   • #{analysis_point}"
    end
    puts

    # Display local gap calculation
    if data[:local_shows] && !data[:local_shows].empty?
      puts "📍 LOCAL GAP CALCULATION:"
      prev_perf = data[:local_shows][:previous_performance]
      puts "   Previous Performance: #{prev_perf[:date]} - #{prev_perf[:venue]}"
      puts "   Track: #{prev_perf[:track_title]} (position #{prev_perf[:position]})"
      puts "   Gap Calculation: #{data[:local_shows][:gap_calculation]}"
      puts

      puts "   Shows in Gap (#{data[:local_shows][:shows_in_gap].count}):"
      if data[:local_shows][:shows_in_gap].any?
        data[:local_shows][:shows_in_gap].each_with_index do |show, idx|
          status_info = []
          status_info << "excluded" if show[:exclude_from_stats]
          status_info << show[:audio_status] if show[:audio_status] != "complete"
          status_suffix = status_info.any? ? " (#{status_info.join(', ')})" : ""

          puts "     #{idx + 1}. #{show[:date]} - #{show[:venue]}#{status_suffix}"
        end
      else
        puts "     (No shows in gap)"
      end
      puts
    end

    # Display remote gap calculation
    if data[:remote_shows] && !data[:remote_shows].empty?
      puts "🌐 REMOTE GAP CALCULATION:"
      prev_perf = data[:remote_shows][:previous_performance]
      puts "   Previous Performance: #{prev_perf[:date]} - #{prev_perf[:venue]}"
      puts "   Track: #{prev_perf[:track_title]} (position #{prev_perf[:position]})"
      puts "   Gap Calculation: #{data[:remote_shows][:gap_calculation]}"
      puts "   Note: #{data[:remote_shows][:note]}" if data[:remote_shows][:note]
      puts

      puts "   Shows in Gap (#{data[:remote_shows][:shows_in_gap].count}):"
      if data[:remote_shows][:shows_in_gap].any?
        data[:remote_shows][:shows_in_gap].each_with_index do |show, idx|
          status_info = []
          status_info << "excluded" if show[:exclude_from_stats]
          status_info << show[:audio_status] if show[:audio_status] != "complete"
          status_suffix = status_info.any? ? " (#{status_info.join(', ')})" : ""

          puts "     #{idx + 1}. #{show[:date]} - #{show[:venue]}#{status_suffix}"
        end
      else
        puts "     (No shows in gap)"
      end
      puts
    end

    puts "🔧 RECOMMENDATIONS:"
    puts "   1. Check if any shows in the gap should be excluded from stats"
    puts "   2. Verify that the previous performance date matches between systems"
    puts "   3. Check if PhishNet has different exclusion rules"
    puts "   4. Consider running: rake gaps:recalculate[#{date}] to refresh local data"
    puts
  end

  desc "Batch investigate multiple tracks for gap discrepancies"
  task :batch_investigate, [ :file_path ] => :environment do |t, args|
    unless args[:file_path]
      puts "Usage: rake gaps:batch_investigate[path/to/tracks.csv]"
      puts "CSV format: date,track_title"
      puts "Example CSV content:"
      puts "2003-02-18,The Moma Dance"
      puts "2003-02-19,Wilson"
      exit 1
    end

    file_path = args[:file_path]

    unless File.exist?(file_path)
      puts "❌ File not found: #{file_path}"
      exit 1
    end

    puts "🔍 Batch investigating gap discrepancies from #{file_path}"
    puts "=" * 80

    investigations = []

    CSV.foreach(file_path, headers: true) do |row|
      date = row["date"]
      track_title = row["track_title"]

      next unless date && track_title

      puts "\n📍 Investigating: #{track_title} on #{date}"

            result = GapInvestigationService.call(date, track_title)

      if result[:error]
        puts "   ❌ Error: #{result[:error]}"
        investigations << {
          date: date,
          track_title: track_title,
          status: "error",
          error: result[:error]
        }
        next
      end

      data = result
      puts "   Local: #{data[:local_gap]}, Remote: #{data[:remote_gap]}"

      investigations << {
        date: date,
        track_title: track_title,
        status: data[:message] == "Gaps match - no discrepancy found" ? "match" : "discrepancy",
        local_gap: data[:local_gap],
        remote_gap: data[:remote_gap],
        analysis: data[:analysis]
      }
    end

    puts "\n" + "=" * 80
    puts "📊 BATCH INVESTIGATION SUMMARY:"
    puts "=" * 80

    matches = investigations.count { |i| i[:status] == "match" }
    discrepancies = investigations.count { |i| i[:status] == "discrepancy" }
    errors = investigations.count { |i| i[:status] == "error" }

    puts "   Total investigated: #{investigations.count}"
    puts "   ✅ Matches: #{matches}"
    puts "   ❌ Discrepancies: #{discrepancies}"
    puts "   ⚠️  Errors: #{errors}"

    if discrepancies > 0
      puts "\n🔍 DISCREPANCIES FOUND:"
      investigations.select { |i| i[:status] == "discrepancy" }.each do |inv|
        puts "   #{inv[:date]} - #{inv[:track_title]}: Local=#{inv[:local_gap]}, Remote=#{inv[:remote_gap]}"
      end
    end

    if errors > 0
      puts "\n⚠️  ERRORS:"
      investigations.select { |i| i[:status] == "error" }.each do |inv|
        puts "   #{inv[:date]} - #{inv[:track_title]}: #{inv[:error]}"
      end
    end
  end
end
