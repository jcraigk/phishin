require "rails_helper"

RSpec.describe TrackSplitService do
  subject(:result) { described_class.call(track, cut_s:, dry_run:) }

  let(:show) { create(:show, date: "1989-05-26") }
  let(:song1) { create(:song, title: "Mike's Song") }
  let(:song2) { create(:song, title: "I Am Hydrogen") }
  let(:track) do
    create(
      :track, show:, title: "Mike's Song > I Am Hydrogen",
              songs: [ song1, song2 ], position: 5, set: "1"
    )
  end
  let(:cut_s) { 20.0 }
  let(:dry_run) { true }
  let(:source) { Rails.root.join("tmp/spec/audio_60s.mp3") }

  before do
    FileUtils.mkdir_p(source.dirname)
    unless File.exist?(source)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=60", "-b:a", "128k", source.to_s,
        exception: true
      )
    end
    track.mp3_audio.attach(
      io: File.open(source), filename: "audio.mp3", content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  describe "dry run" do
    it "renders the first part up to the cut" do
      expect(probe_duration(result[:part1_path])).to be_within(0.3).of(cut_s)
    end

    it "renders the second part from the cut to the end" do
      expect(probe_duration(result[:part2_path])).to be_within(0.3).of(60 - cut_s)
    end

    it "does not create a second track" do
      expect { result }.not_to change(Track, :count)
    end

    it "leaves the original title alone" do
      expect { result }.not_to change { track.reload.title }
    end

    it "reports that nothing was applied" do
      expect(result[:applied]).to be(false)
    end
  end

  describe "applying the split" do
    let(:dry_run) { false }

    it "retitles the original track to the first part" do
      result
      expect(track.reload.title).to eq("Mike's Song")
    end

    it "regenerates the original track's slug" do
      result
      expect(track.reload.slug).to eq("mikes-song")
    end

    it "leaves the original track in its position" do
      expect { result }.not_to change { track.reload.position }
    end

    context "when the split introduces a duplicate title" do
      let(:sibling_title) { "I Am Hydrogen" }

      def hydrogen_slugs
        show.tracks.reload.order(:position)
            .select { it.title == sibling_title }
            .map { [ it.position, it.slug ] }
      end

      context "with an existing instance earlier in the show" do
        before do
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 2, set: "1")
        end

        it "numbers the slugs in position order" do
          result
          expect(hydrogen_slugs).to eq([ [ 2, "i-am-hydrogen" ], [ 6, "i-am-hydrogen-2" ] ])
        end
      end

      context "with an existing instance later in the show" do
        before do
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 8, set: "1")
        end

        it "numbers the slugs in position order" do
          result
          expect(hydrogen_slugs).to eq([ [ 6, "i-am-hydrogen" ], [ 9, "i-am-hydrogen-2" ] ])
        end
      end

      context "with instances on both sides of the split" do
        before do
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 2, set: "1")
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 8, set: "1")
        end

        it "numbers every instance in position order" do
          result
          expect(hydrogen_slugs).to eq(
            [ [ 2, "i-am-hydrogen" ], [ 6, "i-am-hydrogen-2" ], [ 9, "i-am-hydrogen-3" ] ]
          )
        end
      end

      context "when a sibling holds a stale suffixed slug" do
        before do
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 8, set: "1")
            .update_columns(slug: "i-am-hydrogen-2")
        end

        it "does not raise on the unique slug index" do
          expect { result }.not_to raise_error
        end

        it "renumbers both instances in position order" do
          result
          slugs = show.tracks.reload.order(:position)
                      .select { it.title == sibling_title }
                      .map { [ it.position, it.slug ] }
          expect(slugs).to eq([ [ 6, "i-am-hydrogen" ], [ 9, "i-am-hydrogen-2" ] ])
        end
      end

      context "when the second part collides with an already suffixed slug" do
        before do
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 2, set: "1")
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 8, set: "1")
        end

        it "does not raise on the unique slug index" do
          expect { result }.not_to raise_error
        end

        it "renumbers every instance in position order" do
          result
          slugs = show.tracks.reload.order(:position)
                      .select { it.title == sibling_title }
                      .map { it.slug }
          expect(slugs).to eq(
            [ "i-am-hydrogen", "i-am-hydrogen-2", "i-am-hydrogen-3" ]
          )
        end
      end

      context "when the first part duplicates an existing title" do
        before do
          create(:track, show:, title: "Mike's Song", songs: [ song1 ],
                         position: 8, set: "1")
        end

        it "does not raise on the unique slug index" do
          expect { result }.not_to raise_error
        end

        it "numbers the first part's slugs in position order" do
          result
          slugs = show.tracks.reload.order(:position)
                      .select { it.title == "Mike's Song" }
                      .map { [ it.position, it.slug ] }
          expect(slugs).to eq([ [ 5, "mikes-song" ], [ 9, "mikes-song-2" ] ])
        end
      end

      context "with no duplicate" do
        it "leaves the new track's slug unsuffixed" do
          result
          expect(Track.find(result[:new_track_id]).slug).to eq("i-am-hydrogen")
        end

        it "reports no renames" do
          expect(result[:reslugged]).to be_empty
        end
      end

      context "when an untouched track's slug changes" do
        let!(:sibling) do
          create(:track, show:, title: sibling_title, songs: [ song2 ],
                         position: 8, set: "1")
        end

        it "reports the untouched track's moved url" do
          expect(result[:reslugged]).to include(
            hash_including(track_id: sibling.id, from: "i-am-hydrogen",
                           to: "i-am-hydrogen-2")
          )
        end
      end
    end

    it "associates the original track with only the first song" do
      result
      expect(track.reload.songs).to eq([ song1 ])
    end

    it "creates the second track after the original" do
      result
      expect(Track.find(result[:new_track_id])).to have_attributes(
        title: "I Am Hydrogen", position: 6, set: "1"
      )
    end

    it "associates the second track with only the second song" do
      result
      expect(Track.find(result[:new_track_id]).songs).to eq([ song2 ])
    end

    it "gives the second track its own slug" do
      result
      expect(Track.find(result[:new_track_id]).slug).to eq("i-am-hydrogen")
    end

    it "shifts later tracks down to make room" do
      later = create(:track, show:, position: 6, title: "Weekapaug Groove")
      result
      expect(later.reload.position).to eq(7)
    end

    it "sets the original track's duration to the first part" do
      result
      expect(track.reload.duration).to be_within(400).of(cut_s * 1000)
    end

    it "sets the new track's duration to the second part" do
      result
      expect(Track.find(result[:new_track_id]).duration)
        .to be_within(400).of((60 - cut_s) * 1000)
    end

    it "replaces the original track's audio" do
      original_key = track.mp3_audio.blob.key
      result
      expect(track.reload.mp3_audio.blob.key).not_to eq(original_key)
    end

    it "attaches audio to the new track" do
      result
      expect(Track.find(result[:new_track_id]).mp3_audio).to be_attached
    end

    it "writes a backup of the original audio" do
      expect(File.size(result[:backup_path])).to eq(File.size(source))
    end

    it "regenerates the waveform image for both tracks" do
      result
      expect(WaveformImageService).to have_received(:call).twice
    end
  end

  describe "likes" do
    let(:dry_run) { false }

    before { create_list(:like, 2, likable: track) }

    it "duplicates every like onto the new track" do
      result
      expect(Track.find(result[:new_track_id]).likes.count).to eq(2)
    end

    it "leaves the original track's likes in place" do
      result
      expect(track.reload.likes.count).to eq(2)
    end

    it "keeps the counter cache correct on the new track" do
      result
      expect(Track.find(result[:new_track_id]).likes_count).to eq(2)
    end

    it "preserves the like timestamps" do
      created = track.likes.order(:id).first.created_at
      result
      expect(Track.find(result[:new_track_id]).likes.order(:id).first.created_at)
        .to be_within(1.second).of(created)
    end
  end

  describe "track tags" do
    let(:dry_run) { false }
    let(:tag) { create(:tag, name: "SBD") }

    context "with no timestamps" do
      before { create(:track_tag, track:, tag:) }

      it "copies the tag onto the new track" do
        result
        expect(Track.find(result[:new_track_id]).tags).to eq([ tag ])
      end

      it "keeps the tag on the original track" do
        result
        expect(track.reload.tags).to eq([ tag ])
      end
    end

    context "with a tag_sides choice" do
      subject(:result) do
        described_class.call(track, cut_s:, dry_run:, tag_sides:)
      end

      before { create(:track_tag, track:, tag:) }

      context "when set to first" do
        let(:tag_sides) { { "SBD" => "first" } }

        it "keeps the tag on the original track" do
          result
          expect(track.reload.tags).to eq([ tag ])
        end

        it "does not copy it to the new track" do
          result
          expect(Track.find(result[:new_track_id]).tags).to be_empty
        end
      end

      context "when set to second" do
        let(:tag_sides) { { "SBD" => "second" } }

        it "moves the tag to the new track" do
          result
          expect(Track.find(result[:new_track_id]).tags).to eq([ tag ])
        end

        it "removes it from the original track" do
          result
          expect(track.reload.tags).to be_empty
        end
      end

      context "when set to both" do
        let(:tag_sides) { { "SBD" => "both" } }

        it "tags both tracks" do
          result
          expect(track.reload.tags).to eq([ tag ])
          expect(Track.find(result[:new_track_id]).tags).to eq([ tag ])
        end
      end

      context "when set to neither" do
        let(:tag_sides) { { "SBD" => "neither" } }

        it "removes the tag from the original track" do
          result
          expect(track.reload.tags).to be_empty
        end

        it "does not tag the new track" do
          result
          expect(Track.find(result[:new_track_id]).tags).to be_empty
        end

        it "destroys the track_tag rather than orphaning it" do
          expect { result }.to change(TrackTag, :count).by(-1)
        end
      end

      context "when the choice names a tag that is not on the track" do
        let(:tag_sides) { { "Jamcharts" => "second" } }

        it "leaves the untimestamped default in place" do
          result
          expect(track.reload.tags).to eq([ tag ])
          expect(Track.find(result[:new_track_id]).tags).to eq([ tag ])
        end
      end

      context "when a timestamped tag is named" do
        let(:tag_sides) { { "SBD" => "second" } }

        before do
          track.track_tags.destroy_all
          create(:track_tag, track:, tag:, starts_at_second: 5, ends_at_second: 8)
        end

        it "ignores the choice and follows the audio" do
          result
          expect(track.reload.track_tags.count).to eq(1)
          expect(Track.find(result[:new_track_id]).track_tags).to be_empty
        end
      end
    end

    context "with timestamps inside the first part" do
      before { create(:track_tag, track:, tag:, starts_at_second: 5, ends_at_second: 8) }

      it "leaves the tag on the original track" do
        result
        expect(track.reload.track_tags.count).to eq(1)
      end

      it "does not tag the new track" do
        result
        expect(Track.find(result[:new_track_id]).track_tags).to be_empty
      end
    end

    context "with timestamps inside the second part" do
      before { create(:track_tag, track:, tag:, starts_at_second: 30, ends_at_second: 40) }

      it "moves the tag to the new track" do
        result
        expect(track.reload.track_tags).to be_empty
      end

      it "rebases the timestamps onto the new track's clock" do
        result
        expect(Track.find(result[:new_track_id]).track_tags.first)
          .to have_attributes(starts_at_second: 10, ends_at_second: 20)
      end
    end

    context "with timestamps spanning the cut" do
      before { create(:track_tag, track:, tag:, starts_at_second: 15, ends_at_second: 30) }

      it "clamps the original tag to the cut" do
        result
        expect(track.reload.track_tags.first.ends_at_second).to eq(20)
      end

      it "adds the remainder to the new track" do
        result
        expect(Track.find(result[:new_track_id]).track_tags.first)
          .to have_attributes(starts_at_second: 0, ends_at_second: 10)
      end

      it "reports the split tag" do
        expect(result[:notes].join).to include("spanned the cut")
      end
    end
  end

  describe "jam start" do
    let(:dry_run) { false }

    context "when it falls in the first part" do
      before { track.update!(jam_starts_at_second: 12) }

      it "stays on the original track" do
        expect { result }.not_to change { track.reload.jam_starts_at_second }
      end
    end

    context "when it falls in the second part" do
      before { track.update!(jam_starts_at_second: 35) }

      it "is cleared from the original track" do
        result
        expect(track.reload.jam_starts_at_second).to be_nil
      end

      it "moves to the new track rebased onto its clock" do
        result
        expect(Track.find(result[:new_track_id]).jam_starts_at_second).to eq(15)
      end
    end
  end

  describe "playlist entries" do
    let(:dry_run) { false }
    # A playlist is invalid with fewer than two tracks, so it keeps the two the
    # factory seeds and the first is repointed at the track under test. The
    # second doubles as the neighbour that has to shift down.
    let!(:playlist) do
      create(:playlist).tap do |list|
        list.playlist_tracks.order(:position).first
            .update!(track:, position: 1, **entry_bounds)
      end
    end
    let(:entry_bounds) { {} }
    let(:neighbour) { playlist.playlist_tracks.order(:position).last }

    # Entries for the split, in playlist order; the neighbour is not one.
    def split_entries
      playlist.playlist_tracks.order(:position)
              .where(track_id: [ track.id, result[:new_track_id] ])
    end

    context "with a full-track entry" do
      it "becomes two consecutive entries" do
        result
        expect(split_entries.map(&:track_id)).to eq([ track.id, result[:new_track_id] ])
      end

      it "clamps the first entry to the cut" do
        result
        expect(split_entries.first.ends_at_second).to eq(20)
      end

      it "shifts later playlist entries down" do
        # The factory's positions come from a global sequence, so assert on the
        # shift itself rather than on a particular number.
        expect { result }.to change { neighbour.reload.position }.by(1)
      end
    end

    context "with an excerpt inside the first part" do
      let(:entry_bounds) { { starts_at_second: 2, ends_at_second: 10 } }

      it "leaves the entry pointing at the original track" do
        result
        expect(split_entries.map(&:track_id)).to eq([ track.id ])
      end
    end

    context "with an excerpt inside the second part" do
      let(:entry_bounds) { { starts_at_second: 30, ends_at_second: 40 } }

      it "repoints the entry at the new track" do
        result
        expect(split_entries.map(&:track_id)).to eq([ result[:new_track_id] ])
      end

      it "rebases the excerpt onto the new track's clock" do
        result
        expect(split_entries.first)
          .to have_attributes(starts_at_second: 10, ends_at_second: 20)
      end
    end

    context "with an excerpt spanning the cut" do
      let(:entry_bounds) { { starts_at_second: 10, ends_at_second: 30 } }

      it "becomes two entries covering the same audio" do
        result
        expect(split_entries.map do
          [ it.track_id, it.starts_at_second, it.ends_at_second ]
        end).to eq([ [ track.id, 10, 20 ], [ result[:new_track_id], nil, 10 ] ])
      end
    end
  end

  describe "validation" do
    let(:dry_run) { true }

    context "when the cut is too near the start" do
      let(:cut_s) { 1.0 }

      it "refuses to split" do
        expect { result }.to raise_error(described_class::CutOutOfRangeError)
      end
    end

    context "when the cut is too near the end" do
      let(:cut_s) { 59.0 }

      it "refuses to split" do
        expect { result }.to raise_error(described_class::CutOutOfRangeError)
      end
    end

    context "when a part is short but above the minimum" do
      let(:cut_s) { 5.0 }

      it "allows the split" do
        expect { result }.not_to raise_error
      end
    end

    context "when the title has two segues" do
      before { track.update!(title: "Alumni Blues > Letter to Jimmy Page > Alumni Blues") }

      it "refuses to split" do
        expect { result }.to raise_error(described_class::TitleError, /exactly one/)
      end
    end

    context "when the title has no segue" do
      before { track.update!(title: "Mike's Song") }

      it "refuses to split" do
        expect { result }.to raise_error(described_class::TitleError)
      end
    end

    context "when a part matches no song" do
      before { track.update!(title: "Mike's Song > Nonexistent Song") }

      it "names the unmatched part" do
        expect { result }
          .to raise_error(described_class::SongNotFoundError, /Nonexistent Song/)
      end

      it "renders nothing" do
        # An earlier example may have left a render in the output dir, so assert
        # on ffmpeg never being reached rather than on the file's absence.
        allow(Open3).to receive(:capture3).and_call_original
        expect { result }.to raise_error(described_class::SongNotFoundError)
        expect(Open3).not_to have_received(:capture3).with("ffmpeg", *any_args)
      end

      it "names the unmatched part on the error" do
        expect { result }.to raise_error(
          an_instance_of(described_class::SongNotFoundError)
            .and(having_attributes(part_title: "Nonexistent Song"))
        )
      end
    end

    context "with a song override for an unmatched part" do
      subject(:result) do
        described_class.call(track, cut_s:, dry_run:, song_overrides:)
      end

      let(:replacement) { create(:song, title: "Icculus") }
      let(:song_overrides) { { "Nonexistent Song" => replacement.id } }

      before { track.update!(title: "Mike's Song > Nonexistent Song") }

      it "resolves the part to the overridden song" do
        expect(result[:song_ids]).to eq([ song1.id, replacement.id ])
      end

      context "when applied" do
        let(:dry_run) { false }

        it "assigns the overridden song to the new track" do
          new_track = Track.find(result[:new_track_id])
          expect(new_track.songs).to eq([ replacement ])
        end

        it "keeps the part title from the track, not the song" do
          new_track = Track.find(result[:new_track_id])
          expect(new_track.title).to eq("Nonexistent Song")
        end
      end

      context "when the override names a song that does not exist" do
        let(:song_overrides) { { "Nonexistent Song" => 0 } }

        it "still raises" do
          expect { result }.to raise_error(described_class::SongNotFoundError)
        end
      end

      context "when the override is keyed with different casing" do
        let(:song_overrides) { { "nonexistent song" => replacement.id } }

        it "matches case insensitively" do
          expect(result[:song_ids]).to eq([ song1.id, replacement.id ])
        end
      end
    end

    context "when the track has no audio" do
      before { track.mp3_audio.purge }

      it "refuses to split" do
        expect { result }.to raise_error(described_class::MissingAudioError)
      end
    end

    context "when a part title matches a song only in the catalog" do
      let(:track) do
        create(:track, show:, title: "Mike's Song > La Grange",
                       songs: [ song1 ], position: 5, set: "1")
      end

      before { create(:song, title: "La Grange") }

      it "resolves it by title" do
        expect { result }.not_to raise_error
      end
    end
  end

  describe "the -> segue form" do
    let(:dry_run) { false }

    before { track.update!(title: "Mike's Song -> I Am Hydrogen") }

    it "splits on the arrow the same way" do
      result
      expect([ track.reload.title, Track.find(result[:new_track_id]).title ])
        .to eq([ "Mike's Song", "I Am Hydrogen" ])
    end
  end
end
