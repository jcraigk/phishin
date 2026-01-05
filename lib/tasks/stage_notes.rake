namespace :stage_notes do
  desc "Analyze setlist notes and apply Stage Notes tag where warranted"
  task sync: :environment do
    StageNotesSyncService.call(
      date: ENV["DATE"],
      dates: ENV["DATES"],
      start_date: ENV["START_DATE"],
      end_date: ENV["END_DATE"],
      all: ENV["ALL"] == "true",
      dry_run: ENV["DRY_RUN"] == "true",
      verbose: ENV["VERBOSE"] == "true",
      model: ENV.fetch("MODEL", "gpt-4o"),
      delay: ENV.fetch("DELAY", "0").to_f
    )
  end
end
