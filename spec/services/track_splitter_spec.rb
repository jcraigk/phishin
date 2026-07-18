require "rails_helper"

RSpec.describe TrackSplitter do
  subject(:service) { described_class.new(track, split_at_seconds:) }

  let(:show) { create(:show) }
  let(:song1) { create(:song, title: "Fluffhead") }
  let(:song2) { create(:song, title: "Bathtub Gin") }
  let(:track) do
    create(
      :track,
      show:,
      position: 1,
      title: "Fluffhead > Bathtub Gin",
      songs: [ song1, song2 ],
      duration: 2000
    )
  end
  let(:split_at_seconds) { [ 1 ] }
  let(:audio_file) { Rails.root.join("public/placeholders/audio.mp3") }

  before do
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    allow(GapService).to receive(:call)
    track.mp3_audio.attach(io: File.open(audio_file), filename: "audio.mp3")
  end

  context "with invalid input" do
    context "when track has no audio" do
      before { track.update!(audio_status: "missing") }

      it "raises exception" do
        expect { service.call }.to raise_error(RuntimeError, /no audio/)
      end
    end

    context "when split count does not match title" do
      let(:split_at_seconds) { [ 1, 2 ] }

      it "raises exception" do
        expect { service.call }.to raise_error(RuntimeError, /Expected 1 split time/)
      end
    end

    context "when split times are not ascending" do
      let(:track) do
        create(
          :track,
          show:,
          position: 1,
          title: "Fluffhead > Bathtub Gin > Fluffhead",
          songs: [ song1, song2 ],
          duration: 2000
        )
      end
      let(:split_at_seconds) { [ 1, 1 ] }

      it "raises exception" do
        expect { service.call }.to raise_error(RuntimeError, /ascending/)
      end
    end

    context "when a split time exceeds track duration" do
      let(:split_at_seconds) { [ 500 ] }

      it "raises exception" do
        expect { service.call }.to raise_error(RuntimeError, /duration/)
      end
    end

    context "when a segment title matches no song" do
      let(:track) do
        create(
          :track,
          show:,
          position: 1,
          title: "Fluffhead > Unknown Tune",
          songs: [ song1 ],
          duration: 2000
        )
      end

      it "raises exception" do
        expect { service.call }.to raise_error(RuntimeError, /Unknown Tune/)
      end
    end
  end

  context "with dry_run" do
    subject(:service) { described_class.new(track, split_at_seconds:, dry_run: true) }

    it "returns the segment plan without changing anything" do
      segments = service.call
      expect(segments.map { it[:title] }).to eq([ "Fluffhead", "Bathtub Gin" ])
      expect(segments.map { it[:song] }).to eq([ song1, song2 ])
      expect(show.tracks.count).to eq(1)
      expect(track.reload.title).to eq("Fluffhead > Bathtub Gin")
    end
  end

  context "with a valid two-song split" do
    let!(:next_track) { create(:track, show:, position: 2) }

    before { service.call }

    it "turns the original track into the first segment" do
      track.reload
      expect(track.title).to eq("Fluffhead")
      expect(track.songs).to eq([ song1 ])
      expect(track.slug).to eq("fluffhead")
      expect(track.position).to eq(1)
    end

    it "creates a new track for the second segment" do
      new_track = show.tracks.find_by(position: 2)
      expect(new_track.title).to eq("Bathtub Gin")
      expect(new_track.songs).to eq([ song2 ])
      expect(new_track.slug).to eq("bathtub-gin")
      expect(new_track.set).to eq(track.set)
      expect(new_track.mp3_audio).to be_attached
    end

    it "shifts subsequent tracks down" do
      expect(next_track.reload.position).to eq(3)
    end

    it "attaches split audio with nonzero duration to both tracks" do
      show.tracks.where(position: [ 1, 2 ]).each do |t|
        expect(t.mp3_audio).to be_attached
        expect(t.duration).to be > 0
      end
    end

    it "recalculates gaps for the show" do
      expect(GapService).to have_received(:call).with(show, update_previous: true)
    end
  end

  context "with a playlist referencing the combined track" do
    let(:playlist) { create(:playlist) }
    let!(:playlist_track) { create(:playlist_track, playlist:, track:, position: 99) }

    it "refreshes the cached playlist track duration" do
      service.call
      expect(playlist_track.reload.duration).to eq(track.reload.duration)
    end
  end

  context "with track_tags and jam_starts_at_second" do
    let(:tag) { create(:tag) }
    let!(:early_tag) do
      create(:track_tag, track:, tag:, starts_at_second: 0, ends_at_second: 1)
    end
    let!(:late_tag) do
      create(:track_tag, track:, tag: create(:tag), starts_at_second: 1, ends_at_second: 2)
    end

    before do
      track.update!(jam_starts_at_second: 1)
      service.call
    end

    it "keeps tags starting before the split on the first segment" do
      expect(early_tag.reload.track).to eq(track)
      expect(early_tag.starts_at_second).to eq(0)
    end

    it "moves tags starting after the split and adjusts offsets" do
      new_track = show.tracks.find_by(position: 2)
      late_tag.reload
      expect(late_tag.track).to eq(new_track)
      expect(late_tag.starts_at_second).to eq(0)
      expect(late_tag.ends_at_second).to eq(1)
    end

    it "relocates jam_starts_at_second" do
      new_track = show.tracks.find_by(position: 2)
      expect(track.reload.jam_starts_at_second).to be_nil
      expect(new_track.jam_starts_at_second).to eq(0)
    end
  end

  context "when the same song repeats across segments" do
    let(:audio_file) do
      Rails.root.join("tmp/track_splitter_spec_6s.mp3").tap do |path|
        next if File.exist?(path)
        system(
          "ffmpeg -y -hide_banner -loglevel error -f lavfi " \
          "-i sine=frequency=440:duration=6 -q:a 9 #{path}"
        )
      end
    end
    let(:track) do
      create(
        :track,
        show:,
        position: 1,
        title: "Fluffhead > Bathtub Gin > Fluffhead",
        songs: [ song1, song2 ],
        duration: 6000
      )
    end
    let(:split_at_seconds) { [ 2, 4 ] }

    before { service.call }

    it "creates uniquely slugged tracks" do
      expect(show.tracks.order(:position).map(&:slug))
        .to eq(%w[fluffhead bathtub-gin fluffhead-2])
    end
  end
end
