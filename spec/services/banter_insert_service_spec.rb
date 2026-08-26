require "rails_helper"

RSpec.describe BanterInsertService do
  subject(:result) do
    described_class.call(after_track, source_path:, before_track:, notes:, dry_run:)
  end

  let(:show) { create(:show, date: "1991-05-17") }
  let(:sbd) { create(:tag, name: "SBD") }
  let!(:after_track) do
    create(:track, show:, title: "Cavern", position: 2, set: "2", tags: [ sbd ])
  end
  let!(:before_track) { create(:track, show:, title: "Harry Hood", position: 3, set: "2") }
  let(:notes) { "Trey sends off Carl Gerhard" }
  let(:dry_run) { false }
  let(:source_path) { Rails.root.join("tmp/spec/banter_source.flac") }

  before do
    create(:tag, name: "Banter")
    create(:song, title: "Banter")
    create(:track, show:, title: "Magilla", position: 1, set: "2")
    fixture = Rails.root.join("tmp/spec/banter_source.flac")
    FileUtils.mkdir_p(fixture.dirname)
    unless File.exist?(fixture)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=3", fixture.to_s, exception: true
      )
    end
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    allow(Rails.cache).to receive(:clear)
  end

  it "inserts a Banter track right after the anchor and shifts the rest" do
    result
    titles = show.tracks.order(:position).pluck(:position, :title)
    expect(titles).to eq(
      [ [ 1, "Magilla" ], [ 2, "Cavern" ], [ 3, "Banter" ], [ 4, "Harry Hood" ] ]
    )
  end

  it "attaches the rendered mp3 and measures its duration" do
    track = Track.find(result[:track_id])
    expect(track.mp3_audio).to be_attached
    expect(track.duration).to be_within(200).of(3000)
  end

  it "tags the track as Banter with the notes and copies the anchor's SBD tag" do
    track = Track.find(result[:track_id])
    expect(track.track_tags.map { |tt| [ tt.tag.name, tt.notes ] })
      .to contain_exactly([ "Banter", notes ], [ "SBD", nil ])
  end

  it "reports the placement" do
    expect(result).to include(
      applied: true, date: "1991-05-17", title: "Banter", position: 3, set: "2",
      after_title: "Cavern"
    )
  end

  context "when the anchor has no SBD tag" do
    let!(:after_track) { create(:track, show:, title: "Cavern", position: 2, set: "2") }

    it "does not add one" do
      expect(Track.find(result[:track_id]).tags.map(&:name)).to eq([ "Banter" ])
    end
  end

  context "with another song" do
    subject(:result) do
      described_class.call(after_track, source_path:, before_track:, title: "Fee", song:)
    end

    let(:song) { create(:song, title: "Fee") }

    it "uses that song and title but still tags as Banter" do
      track = Track.find(result[:track_id])
      expect([ track.title, track.songs.map(&:title), track.tags.map(&:name) ])
        .to eq([ "Fee", [ "Fee" ], [ "Banter", "SBD" ] ])
    end
  end

  context "with only a before-track (start of set)" do
    subject(:result) do
      described_class.call(nil, source_path:, before_track: show.tracks.find_by!(title: "Magilla"))
    end

    it "inserts at that track's position and shifts the set down" do
      result
      titles = show.tracks.order(:position).pluck(:position, :title)
      expect(titles).to eq(
        [ [ 1, "Banter" ], [ 2, "Magilla" ], [ 3, "Cavern" ], [ 4, "Harry Hood" ] ]
      )
    end
  end

  context "with only an after-track (end of set)" do
    subject(:result) { described_class.call(before_track, source_path:) }

    it "appends after it" do
      expect(show.tracks.find(result[:track_id]).position).to eq(4)
    end
  end

  context "with neither anchor" do
    subject(:result) { described_class.call(nil, source_path:) }

    it "refuses" do
      expect { result }.to raise_error(described_class::Error, /at least one side/)
    end
  end

  context "with an explicit set" do
    subject(:result) { described_class.call(after_track, source_path:, before_track:, set: "E") }

    it "uses it instead of the anchor's set" do
      expect(Track.find(result[:track_id]).set).to eq("E")
    end
  end

  context "when run twice" do
    it "inserts once and reports the second run as already inserted" do
      first = described_class.call(after_track, source_path:, before_track:)
      expect { described_class.call(after_track, source_path:, before_track:) }
        .to raise_error(described_class::AlreadyInserted, /already inserted/)
      expect(show.tracks.where(title: "Banter").pluck(:id)).to eq([ first[:track_id] ])
    end

    it "does not double up a start-of-set insert either" do
      magilla = show.tracks.find_by!(title: "Magilla")
      described_class.call(nil, source_path:, before_track: magilla)
      # The anchor has moved down one slot, as it will have on a real re-run.
      expect { described_class.call(nil, source_path:, before_track: magilla.reload) }
        .to raise_error(described_class::AlreadyInserted)
      expect(show.tracks.where(title: "Banter").count).to eq(1)
    end
  end

  context "when the insert fails partway" do
    it "leaves the other tracks' positions untouched" do
      allow(TrackInserter).to receive(:new).and_wrap_original do |m, *args, **kw|
        inserter = m.call(*args, **kw)
        allow(inserter).to receive(:call) do
          inserter.send(:shift_track_positions)
          raise ActiveRecord::RecordNotUnique, "slug taken"
        end
        inserter
      end
      expect { result }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(show.tracks.order(:position).pluck(:position, :title))
        .to eq([ [ 1, "Magilla" ], [ 2, "Cavern" ], [ 3, "Harry Hood" ] ])
    end
  end

  context "with an mp3 source" do
    let(:source_path) { Rails.root.join("tmp/spec/banter_source.mp3") }

    before do
      unless File.exist?(source_path)
        system("ffmpeg", "-y", "-v", "error", "-i", Rails.root.join("tmp/spec/banter_source.flac").to_s,
               "-b:a", "128k", source_path.to_s, exception: true)
      end
    end

    it "attaches it as is instead of re-encoding" do
      result
      expect(FileUtils.compare_file(source_path, result[:output_path])).to be(true)
    end
  end

  context "when the earlier copy was retitled and trimmed" do
    it "still counts as already inserted" do
      first = described_class.call(after_track, source_path:, before_track:)
      Track.find(first[:track_id]).update_columns(title: "Intro", duration: 1500)
      expect { described_class.call(after_track, source_path:, before_track:) }
        .to raise_error(described_class::AlreadyInserted)
    end
  end

  context "when a same-title slug is already taken out of sequence" do
    it "renumbers the existing slugs and inserts" do
      create(:track, show:, title: "Banter", slug: "banter-2", position: 4, set: "2")
      show.tracks.find_by!(title: "Harry Hood").update_column(:position, 3)
      result
      expect(show.tracks.order(:position).pluck(:position, :title, :slug)).to eq(
        [ [ 1, "Magilla", "magilla" ], [ 2, "Cavern", "cavern" ], [ 3, "Banter", "banter" ],
          [ 4, "Harry Hood", "harry-hood" ], [ 5, "Banter", "banter-2" ] ]
      )
    end
  end

  context "with dry_run" do
    let(:dry_run) { true }

    it "renders the mp3 without inserting anything" do
      expect { result }.not_to change(Track, :count)
      expect(File).to exist(result[:output_path])
      expect(result).to include(applied: false, track_id: nil)
    end
  end

  context "when the before-track is not right after the anchor" do
    let!(:before_track) { create(:track, show:, title: "Harry Hood", position: 5, set: "2") }

    it "refuses" do
      expect { result }.to raise_error(described_class::Error, /expected Harry Hood right after Cavern/)
    end
  end

  context "when the source file is missing" do
    let(:source_path) { Pathname.new("/nonexistent/banter.flac") }

    it "refuses" do
      expect { result }.to raise_error(described_class::Error, /No source file/)
    end
  end
end
