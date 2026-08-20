require "rails_helper"

RSpec.describe TrackEdit do
  let(:track) { create(:track) }

  # "split" and "combine" no longer have admin jobs: the admin UI moves an
  # existing boundary but never creates or removes one, so both were removed
  # from the browser and live on only in lib/tasks/split_scan.rake. The
  # operations stay in the vocabulary because a TrackEdit written before that
  # change still carries them, and the model validates on inclusion - dropping
  # them would make history invalid.
  let(:retired_operations) { %w[split combine] }

  it "accepts every operation in the vocabulary" do
    described_class::OPERATIONS.each do |operation|
      expect(build(:track_edit, track:, operation:)).to be_valid
    end
  end

  it "rejects an operation outside the vocabulary" do
    expect(build(:track_edit, track:, operation: "rename")).not_to be_valid
  end


  # Read off the filesystem rather than restated, so adding an audio-affecting
  # job without giving it an operation fails here instead of silently going
  # unlogged. Jobs that never touch audio are listed as exempt, which forces a
  # deliberate decision about each new one.
  it "covers every audio-affecting admin job" do
    exempt = %w[
      edit_cover_art generate_cover_art import_show job_audio_cleanup publish_show
      recompute_gaps regenerate_cover_art_prompt select_cover_art tagin_drift tagin_sync
    ]
    jobs = Dir[Rails.root.join("app/jobs/admin/*_job.rb")]
             .map { File.basename(it, "_job.rb") }
             .reject { exempt.include?(it) }

    expect(jobs.sort).to eq((described_class::OPERATIONS - retired_operations).sort)
  end

  it "still accepts a retired operation so existing history stays valid" do
    retired_operations.each do |operation|
      expect(build(:track_edit, operation:)).to be_valid
    end
  end

  # The point of the whole record: a combine destroys a track row, and the
  # history of that combine has to survive its own subject.
  context "when the track it describes is destroyed" do
    let(:payload) { { "duration_before_s" => 150.0, "backup_path" => "/tmp/original.mp3" } }
    let(:show_id) { track.show_id }
    let!(:edit) { create(:track_edit, track:, operation: "combine", payload:) }

    before { track.destroy! }

    it "survives with its track reference nullified" do
      expect(edit.reload.track_id).to be_nil
      expect(described_class.exists?(edit.id)).to be(true)
    end

    it "keeps its payload and its show intact" do
      expect(edit.reload.payload).to eq(payload)
      expect(edit.show_id).to eq(show_id)
    end
  end

  it "still reaches its show after its track is gone" do
    edit = create(:track_edit, track:, operation: "combine")
    show = track.show
    track.destroy!
    expect(show.track_edits.reload).to include(edit)
  end

  it "refuses to be destroyed" do
    edit = create(:track_edit, track:)
    expect { edit.destroy }.to raise_error(described_class::ImmutableError)
    expect(described_class.exists?(edit.id)).to be(true)
  end

  it "refuses to be deleted" do
    edit = create(:track_edit, track:)
    expect { edit.delete }.to raise_error(described_class::ImmutableError)
    expect(described_class.exists?(edit.id)).to be(true)
  end

  it "refuses to be updated" do
    edit = create(:track_edit, track:, operation: "trim")
    expect { edit.update!(operation: "split") }
      .to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(edit.reload.operation).to eq("trim")
  end

  it "keeps a nullable user and admin job optional" do
    expect(build(:track_edit, track:, user: nil, admin_job: nil)).to be_valid
  end

  it "orders newest first" do
    older = create(:track_edit, track:, created_at: 2.days.ago)
    newer = create(:track_edit, track:, created_at: 1.day.ago)
    expect(described_class.newest_first.to_a).to eq([ newer, older ])
  end
end
