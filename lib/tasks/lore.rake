namespace :lore do
  desc "Analyze setlist notes and apply Lore tag where warranted"
  task sync: :environment do
    opts = {
      date: ENV["DATE"],
      dates: ENV["DATES"],
      start_date: ENV["START_DATE"],
      end_date: ENV["END_DATE"],
      all: ENV["ALL"] == "true",
      dry_run: ENV["DRY_RUN"] == "true",
      verbose: ENV["VERBOSE"] == "true"
    }
    opts[:model] = ENV["MODEL"] if ENV["MODEL"]
    opts[:delay] = ENV["DELAY"].to_f if ENV["DELAY"]

    LoreSyncService.call(**opts)
  end
end
