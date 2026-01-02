namespace :stage_notes do
  desc "Analyze setlist notes and apply Stage Notes tag where warranted"
  task sync: :environment do
    StageNotesSyncService.call(
      date: ENV["DATE"],
      start_date: ENV["START_DATE"],
      end_date: ENV["END_DATE"],
      all: ENV["ALL"] == "true",
      dry_run: ENV["DRY_RUN"] == "true"
    )
  end
end
