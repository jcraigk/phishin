require "rails_helper"

RSpec.describe Admin::TaginDriftJob do
  let(:admin_job) { create(:admin_job, kind: "tagin_drift") }
  let(:tag_name) { "Guest" }
  let!(:tag) { create(:tag, name: tag_name) }
  let(:show) { create(:show, date: "2024-07-19") }
  let!(:track) { create(:track, show:, position: 1, slug: "in-both") }
  let!(:orphan) { create(:track, show:, position: 2, slug: "db-only") }
  let(:sheet_only_url) { "#{App.base_url}/2024-07-19/sheet-only" }

  def stub_sheet(rows)
    allow(GoogleSpreadsheetFetcher).to receive(:call) do |_id, range, **|
      range.start_with?("#{tag_name}!") ? rows : []
    end
  end

  def drift
    admin_job.reload.payload["drift"]
  end

  before do
    track.track_tags.create!(tag:, notes: "same notes")
    orphan.track_tags.create!(tag:, notes: "db only")

    stub_sheet(
      [
        { "URL" => track.url, "Notes" => "same notes" },
        { "URL" => sheet_only_url, "Notes" => "sheet only" }
      ]
    )
  end

  describe "drift categories" do
    it "reports a tag present in the database but absent from the sheet" do
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["missing_in_sheet"].map { |e| e["url"] }).to eq([ orphan.url ])
    end

    it "reports a row present in the sheet but absent from the database" do
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["missing_in_db"].map { |e| e["url"] }).to eq([ sheet_only_url ])
    end

    it "reports no mismatch when the sheet and database agree" do
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["mismatched"]).to eq([])
    end

    it "reports a field mismatch" do
      track.track_tags.first.update!(notes: "different")
      described_class.new.perform(admin_job.id)
      entry = drift[tag_name]["mismatched"].first
      expect(entry["url"]).to eq(track.url)
      expect(entry["field_diffs"]["notes"]).to eq("db" => "different", "sheet" => "same notes")
    end

    it "reports a timestamp mismatch in seconds" do
      track.track_tags.first.update!(starts_at_second: 42)
      stub_sheet([ { "URL" => track.url, "Notes" => "same notes", "Starts At" => "1:30" } ])
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["mismatched"].first["field_diffs"]["starts_at_second"])
        .to eq("db" => 42, "sheet" => 90)
    end

    it "omits tags with no drift" do
      orphan.track_tags.destroy_all
      stub_sheet([ { "URL" => track.url, "Notes" => "same notes" } ])
      described_class.new.perform(admin_job.id)
      expect(drift).to eq({})
    end
  end

  describe "entry contents" do
    it "links a database-side entry to its track" do
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["missing_in_sheet"].first)
        .to include("url" => orphan.url, "track_title" => orphan.title, "show_date" => "2024-07-19")
    end

    it "resolves a sheet-side entry that matches an existing track" do
      track.track_tags.destroy_all
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["missing_in_db"])
        .to include(hash_including("url" => track.url, "track_title" => track.title))
    end

    it "leaves a sheet-side entry unresolved when no track matches the url" do
      entry = nil
      described_class.new.perform(admin_job.id)
      entry = drift[tag_name]["missing_in_db"].find { |e| e["url"] == sheet_only_url }
      expect(entry).to include("track_title" => nil, "show_date" => nil)
    end
  end

  describe "normalization parity with the sync" do
    before { orphan.track_tags.destroy_all }

    it "ignores a trailing period the model strips on write" do
      track.track_tags.first.update!(notes: "A tease")
      stub_sheet([ { "URL" => track.url, "Notes" => "A tease." } ])
      described_class.new.perform(admin_job.id)
      expect(drift).to eq({})
    end

    it "ignores a curly quote the sync rewrites on write" do
      track.track_tags.first.update!(notes: "Rockin' Robin")
      stub_sheet([ { "URL" => track.url, "Notes" => "Rockin’ Robin" } ])
      described_class.new.perform(admin_job.id)
      expect(drift).to eq({})
    end

    it "ignores an HTML entity the model decodes on write" do
      track.track_tags.first.update!(notes: "Bruce & Sons")
      stub_sheet([ { "URL" => track.url, "Notes" => "Bruce &amp; Sons" } ])
      described_class.new.perform(admin_job.id)
      expect(drift).to eq({})
    end

    it "agrees with what a real sync would write" do
      stub_sheet([ { "URL" => track.url, "Notes" => "Fluffhead by Trey Anastasio." } ])
      TrackTagSyncService.call(tag_name, [ { "URL" => track.url, "Notes" => "Fluffhead by Trey Anastasio." } ])
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]&.fetch("mismatched", [])).to be_blank
    end
  end

  describe "tags that allow multiple entries per track" do
    let(:tag_name) { "Tease" }

    before do
      TrackTag.destroy_all
      track.track_tags.create!(tag:, notes: "First tease")
      track.track_tags.create!(tag:, notes: "Second tease")
    end

    it "matches each sheet row to its own tag" do
      stub_sheet(
        [
          { "URL" => track.url, "Notes" => "First tease" },
          { "URL" => track.url, "Notes" => "Second tease" }
        ]
      )
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]).to be_nil
    end

    it "reports only the tease absent from the sheet" do
      stub_sheet([ { "URL" => track.url, "Notes" => "First tease" } ])
      described_class.new.perform(admin_job.id)
      expect(drift[tag_name]["missing_in_sheet"].map { |e| e["notes"] }).to eq([ "Second tease" ])
    end
  end

  describe "read-only guarantee" do
    def tag_row_state
      {
        track_tags: TrackTag.order(:id).pluck(:id, :tag_id, :track_id, :notes,
                                              :starts_at_second, :ends_at_second, :transcript),
        show_tags: ShowTag.order(:id).pluck(:id, :tag_id, :show_id, :notes),
        tags: Tag.order(:id).pluck(:id, :name, :tracks_count, :shows_count)
      }
    end

    it "creates, updates, and destroys no tag rows" do
      track.track_tags.first.update!(notes: "different")
      before_state = tag_row_state

      described_class.new.perform(admin_job.id)

      expect(tag_row_state).to eq(before_state)
    end

    it "changes no tag row counts" do
      admin_job
      expect { described_class.new.perform(admin_job.id) }
        .not_to change { [ TrackTag.count, ShowTag.count, Tag.count ] }
    end

    it "does not clear the cache the sync clears" do
      allow(Rails.cache).to receive(:clear)
      described_class.new.perform(admin_job.id)
      expect(Rails.cache).not_to have_received(:clear)
    end

    it "does not run the sync service" do
      allow(TrackTagSyncService).to receive(:call)
      described_class.new.perform(admin_job.id)
      expect(TrackTagSyncService).not_to have_received(:call)
    end

    it "requests the sheet without writing to it" do
      described_class.new.perform(admin_job.id)
      expect(GoogleSpreadsheetFetcher).to have_received(:call)
        .with(ENV["TAGIN_GSHEET_ID"], "#{tag_name}!A1:G5000", headers: true)
    end
  end

  describe "job lifecycle" do
    it "completes the admin job" do
      described_class.new.perform(admin_job.id)
      expect(admin_job.reload).to have_attributes(status: "done", progress: 100)
    end

    it "summarizes how many tags drifted" do
      described_class.new.perform(admin_job.id)
      expect(admin_job.reload.message).to eq("1 of #{TAGIN_TAGS.size} tags have drift")
    end

    it "reports the tag being compared" do
      seen = nil
      allow(GoogleSpreadsheetFetcher).to receive(:call) do |_id, range, **|
        seen ||= admin_job.reload.slice(:progress, :message) if range.start_with?("#{TAGIN_TAGS.first}!")
        []
      end
      described_class.new.perform(admin_job.id)
      expect(seen).to eq("progress" => 0, "message" => "Comparing #{TAGIN_TAGS.first}")
    end

    it "records a per-tag failure without losing the other tags" do
      allow(GoogleSpreadsheetFetcher).to receive(:call) do |_id, range, **|
        raise "sheet tab missing" if range.start_with?("#{tag_name}!")
        []
      end
      described_class.new.perform(admin_job.id)
      expect(admin_job.reload.payload["errors"])
        .to eq([ { "tag" => tag_name, "error" => "sheet tab missing" } ])
    end

    it "fails the job when every tag fails" do
      allow(GoogleSpreadsheetFetcher).to receive(:call)
        .and_raise("No valid credentials found and not in development environment")
      expect { described_class.new.perform(admin_job.id) }
        .to raise_error(Admin::TaginDriftJob::DriftFailed)
      expect(admin_job.reload.status).to eq("failed")
    end

    it "names the credential when every tag fails" do
      allow(GoogleSpreadsheetFetcher).to receive(:call)
        .and_raise("No valid credentials found and not in development environment")
      expect { described_class.new.perform(admin_job.id) }
        .to raise_error(Admin::TaginDriftJob::DriftFailed)
      expect(admin_job.reload.message).to include("GOOGLE_SPREADSHEET_CREDS")
    end
  end

  describe "payload size" do
    it "caps the entries kept per category and records the true total" do
      stub_const("#{described_class}::MAX_ENTRIES", 2)
      extras = Array.new(5) do |n|
        create(:track, show:, position: n + 10, slug: "extra-#{n}")
          .tap { |t| t.track_tags.create!(tag:, notes: "extra #{n}") }
      end
      described_class.new.perform(admin_job.id)
      report = drift[tag_name]
      expect(report["missing_in_sheet"].size).to eq(2)
      expect(report["counts"]["missing_in_sheet"]).to eq(extras.size + 1)
      expect(report["truncated"]).to be(true)
    end
  end
end
