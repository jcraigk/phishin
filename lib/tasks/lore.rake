namespace :lore do
  desc "Analyze setlist notes and apply Lore tag where warranted"
  task sync: :environment do
    LoreSyncService.call(
      date: ENV["DATE"],
      dates: ENV["DATES"],
      start_date: ENV["START_DATE"],
      end_date: ENV["END_DATE"],
      all: ENV["ALL"] == "true",
      dry_run: ENV["DRY_RUN"] == "true",
      verbose: ENV["VERBOSE"] == "true",
      model: ENV.fetch("MODEL", nil),
      delay: ENV.fetch("DELAY", nil).to_f
    )
  end
end
