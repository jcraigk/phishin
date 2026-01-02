namespace :venues do
  desc "Generate map snapshots for all venues with coordinates"
  task generate_maps: :environment do
    relation = Venue.where.not(latitude: nil, longitude: nil)
    pbar = ProgressBar.create(
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
    )

    relation.find_each do |venue|
      VenueMapSnapshotJob.perform_async(venue.id)
      pbar.increment
    end

    pbar.finish
    puts "Enqueued #{relation.count} venue map snapshot jobs"
  end

  desc "Generate map snapshots for a specific venue by ID or slug"
  task :generate_map, [ :venue_identifier ] => :environment do |_t, args|
    venue = Venue.find_by(id: args[:venue_identifier]) ||
            Venue.find_by(slug: args[:venue_identifier])

    if venue.nil?
      puts "Venue not found: #{args[:venue_identifier]}"
      exit 1
    end

    unless venue.has_coordinates?
      puts "Venue #{venue.name} has no coordinates"
      exit 1
    end

    VenueMapSnapshotJob.perform_async(venue.id)
    puts "Enqueued map snapshot job for #{venue.name}"
  end
end
