namespace :bustout_tags do
  desc "Delete all bustout tags (with confirmation)"
  task purge: :environment do
    bustout_tag = Tag.find_by(name: "Bustout")
    puts "Deleting all bustout tags..."
    TrackTag.where(tag: bustout_tag).destroy_all
  end

  desc "Regenerate bustout tags for all shows"
  task regenerate: :environment do
    puts "Starting bustout tag regeneration for all shows..."

    total_shows = Show.published.count
    processed = 0

    pbar = ProgressBar.create(
      total: total_shows,
      format: "%a %B %c/%C %p%% %E"
    )

    puts "Running BustoutTagService on all published shows..."

    Show.published.order(:date).each do |show|
      begin
        BustoutTagService.call(show)
        processed += 1
        pbar.increment
      rescue => e
        puts "\nError processing show #{show.date}: #{e.message}"
        pbar.increment
      end
    end

    pbar.finish

    puts "\n✅ Bustout tag regeneration completed!"
    puts "Processed #{total_shows} shows"

    # Show some statistics
    total_bustout_tags = TrackTag.joins(:tag).where(tags: { name: "Bustout" }).count
    puts "Total bustout tags now: #{total_bustout_tags}"
  end
end
