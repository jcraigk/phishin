require "rails_helper"
require "rake"

RSpec.describe "notes:fix_html_entities" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("notes:fix_html_entities")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/notes.rake")
  end

  def run_task
    expect { Rake::Task["notes:fix_html_entities"].execute }.to output.to_stdout
  end

  # Writes raw values with SQL to bypass model normalization
  def store_raw(record, column, value)
    record.class.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(
        [ "UPDATE #{record.class.table_name} SET #{column} = ? WHERE id = ?", value, record.id ]
      )
    )
  end

  it "decodes named entities in tag notes" do
    track_tag = create(:track_tag)
    store_raw(track_tag, :notes, "Big Head Todd &amp; the Monsters")
    show_tag = create(:show_tag)
    store_raw(show_tag, :notes, "Trey said &quot;hello&quot;")

    run_task

    expect(track_tag.reload.notes).to eq("Big Head Todd & the Monsters")
    expect(show_tag.reload.notes).to eq('Trey said "hello"')
  end

  it "decodes numeric and double-encoded entities in transcripts" do
    track_tag = create(:track_tag)
    store_raw(track_tag, :transcript, "It&#39;s the story of Icculus &amp;amp; friends")

    run_task

    expect(track_tag.reload.transcript).to eq("It's the story of Icculus & friends")
  end

  it "decodes entities in show taper and admin notes" do
    show = create(:show)
    store_raw(show, :taper_notes, "Schoeps &gt; Lunatec &gt; DAT")
    store_raw(show, :admin_notes, "Source A &amp; B spliced")

    run_task

    expect(show.reload.taper_notes).to eq("Schoeps > Lunatec > DAT")
    expect(show.reload.admin_notes).to eq("Source A & B spliced")
  end

  it "leaves plain ampersands and non-entity text unchanged" do
    track_tag = create(:track_tag)
    store_raw(track_tag, :notes, "Mike & Trey trade licks; R&B jam")

    run_task

    expect(track_tag.reload.notes).to eq("Mike & Trey trade licks; R&B jam")
  end

  it "makes no changes when DRY_RUN=true" do
    track_tag = create(:track_tag)
    store_raw(track_tag, :notes, "Big Head Todd &amp; the Monsters")
    ENV["DRY_RUN"] = "true"

    run_task

    expect(track_tag.reload.notes).to eq("Big Head Todd &amp; the Monsters")
  ensure
    ENV.delete("DRY_RUN")
  end
end
