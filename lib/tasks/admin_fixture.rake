# Repeatable local test setup for the admin UI. The work lives in
# AdminFixture; these are just the entry points.
#
#   rails admin_fixture:setup     # snapshot, then download the blob files
#   rails admin_fixture:status    # what is on disk and what has drifted
#   rails admin_fixture:restore   # roll the shows back to the snapshot
namespace :admin_fixture do
  desc "Snapshot the fixture shows and download their attachment files"
  task setup: :environment do
    AdminFixture.setup
  end

  desc "Show what is downloaded and what has drifted from the snapshot"
  task status: :environment do
    AdminFixture.status
  end

  desc "Restore the fixture shows from their snapshots"
  task restore: :environment do
    AdminFixture.restore_all
  end
end
