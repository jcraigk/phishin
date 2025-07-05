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
        PerformanceGapService.call(show)
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
  task update_show: :environment do
    date = ENV["DATE"]
    unless date
      puts "Usage: DATE=YYYY-MM-DD rake performance_gaps:update_show"
      exit 1
    end

    show = Show.find_by(date: Date.parse(date))
    unless show
      puts "Show not found for date: #{date}"
      exit 1
    end

    puts "Recalculating gaps for show: #{show.date} at #{show.venue.name}"

    PerformanceGapService.call(show)
  end
end
