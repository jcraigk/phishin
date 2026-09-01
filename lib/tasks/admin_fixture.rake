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
