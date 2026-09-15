require "rails_helper"

RSpec.describe UnattachedBlobCleanupJob do
  def blob(content, filename, age: nil)
    b = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename:, content_type: "audio/mpeg"
    )
    b.update_column(:created_at, age) if age
    b
  end

  def purged_ids
    Sidekiq::Queues.jobs_by_queue.values.flatten
                   .select { it["wrapped"] == "ActiveStorage::PurgeJob" }
                   .map { it.dig("args", 0, "arguments", 0, "_aj_globalid") }
  end

  it "purges old unattached blobs and leaves attached and fresh ones" do
    old_orphan = blob("orphan", "orphan.mp3", age: 2.days.ago)
    fresh_orphan = blob("fresh", "fresh.mp3")
    attached = blob("art", "art.png", age: 2.days.ago)
    create(:show).cover_art_candidates.attach(attached)

    described_class.new.perform

    expect(purged_ids).to include(match(%r{Blob/#{old_orphan.id}\z}))
    expect(purged_ids).not_to include(match(%r{Blob/#{fresh_orphan.id}\z}))
    expect(purged_ids).not_to include(match(%r{Blob/#{attached.id}\z}))
  end
end
