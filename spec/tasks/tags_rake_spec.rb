require "rails_helper"
require "rake"

RSpec.describe "tags:normalize_notes" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("tags:normalize_notes")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/tags.rake")
  end

  def run_task
    expect { Rake::Task["tags:normalize_notes"].execute }.to output.to_stdout
  end

  # Writes raw notes with SQL since normalization applies even in update_columns
  def store_raw_notes(record, notes)
    record.class.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(
        [ "UPDATE #{record.class.table_name} SET notes = ? WHERE id = ?", notes, record.id ]
      )
    )
  end

  it "strips trailing periods from existing single-sentence notes" do
    track_tag = create(:track_tag)
    store_raw_notes(track_tag, "Trey on a mini drum kit.")
    show_tag = create(:show_tag)
    store_raw_notes(show_tag, "Fish appeared in a dress.")

    run_task

    expect(track_tag.reload.notes).to eq("Trey on a mini drum kit")
    expect(show_tag.reload.notes).to eq("Fish appeared in a dress")
  end

  it "leaves multi-sentence notes unchanged" do
    track_tag = create(:track_tag)
    store_raw_notes(track_tag, "White coils descended. Dancers appeared.")

    run_task

    expect(track_tag.reload.notes).to eq("White coils descended. Dancers appeared.")
  end

  it "makes no changes when DRY_RUN=true" do
    track_tag = create(:track_tag)
    store_raw_notes(track_tag, "Trey on a mini drum kit.")
    ENV["DRY_RUN"] = "true"

    run_task

    expect(track_tag.reload.notes).to eq("Trey on a mini drum kit.")
  ensure
    ENV.delete("DRY_RUN")
  end
end
