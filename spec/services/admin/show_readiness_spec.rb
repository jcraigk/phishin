require "rails_helper"

RSpec.describe Admin::ShowReadiness do
  let(:show) { create(:show, date: "2025-08-01", published: false) }

  def attach_audio(track)
    track.mp3_audio.attach(
      io: StringIO.new("mp3"),
      filename: "a.mp3",
      content_type: "audio/mpeg"
    )
    track.png_waveform.attach(
      io: StringIO.new("png"),
      filename: "a.png",
      content_type: "image/png"
    )
    track.update!(duration: 100_000, audio_status: "complete")
  end

  def attach_cover_art(show)
    show.cover_art.attach(io: StringIO.new("img"), filename: "a.png", content_type: "image/png")
    show.album_cover.attach(io: StringIO.new("img"), filename: "b.png", content_type: "image/png")
  end

  def ready_show
    attach_cover_art(show)
    track = create(:track, show:, position: 1, songs: [ create(:song) ])
    attach_audio(track)
    show.reload
  end

  it "lists issues for an empty draft" do
    show.update!(venue: nil, tour: nil)
    result = described_class.call(show)
    expect(result[:ready]).to be(false)
    expect(result[:issues]).to include(
      "No venue assigned",
      "No tour assigned",
      "No tracks",
      "No cover art selected"
    )
  end

  it "flags a missing album cover separately from cover art" do
    show.cover_art.attach(io: StringIO.new("img"), filename: "a.png", content_type: "image/png")
    result = described_class.call(show)
    expect(result[:issues]).to include("No album cover composited")
    expect(result[:issues]).not_to include("No cover art selected")
  end

  it "flags tracks with missing audio" do
    track = create(:track, show:, position: 1, songs: [ create(:song) ])
    result = described_class.call(show)
    expect(result[:issues].join("\n")).to include("#{track.position}. #{track.title}: no audio")
  end

  it "flags a track with no songs" do
    ready_show
    track = show.tracks.first
    track.songs_tracks.destroy_all
    result = described_class.call(show.reload)
    expect(result[:ready]).to be(false)
    expect(result[:issues].join("\n")).to include("#{track.position}. #{track.title}: no songs")
  end

  it "flags a track with attached audio but zero duration" do
    ready_show
    track = show.tracks.first
    track.update_column(:duration, 0)
    result = described_class.call(show.reload)
    expect(result[:issues].join("\n")).to include("#{track.position}. #{track.title}: zero duration")
  end

  it "flags a track whose audio has no waveform" do
    ready_show
    show.tracks.first.png_waveform.detach
    result = described_class.call(show.reload)
    expect(result[:issues].join("\n")).to include("no waveform")
  end

  it "flags a track with a blank set" do
    ready_show
    show.tracks.first.update_column(:set, "")
    result = described_class.call(show.reload)
    expect(result[:issues].join("\n")).to include("blank set")
  end

  it "flags a track whose audio_status column still says missing" do
    ready_show
    show.tracks.first.update_column(:audio_status, "missing")
    result = described_class.call(show.reload)
    expect(result[:issues].join("\n")).to include("audio not processed")
  end

  it "reports per-problem entries naming the track" do
    ready_show
    track = show.tracks.first
    track.songs_tracks.destroy_all
    problem = described_class.call(show.reload)[:problems].find { |p| p[:code] == "track_no_songs" }
    expect(problem).to include(
      scope: "track",
      track_id: track.id,
      position: track.position,
      title: track.title
    )
  end

  it "is ready when everything is present" do
    result = described_class.call(ready_show)
    expect(result[:issues]).to eq([])
    expect(result[:ready]).to be(true)
  end

  it "does not mutate the show" do
    ready_show
    expect { described_class.call(show.reload) }
      .not_to change { show.reload.attributes }
  end

  it "reports ready only for a show that survives publishing" do
    show = ready_show
    expect(described_class.call(show)[:ready]).to be(true)
    expect { show.update!(published: true) }.not_to raise_error
    expect(show.reload.published).to be(true)
    expect(show.tracks.map { |t| t.valid? }).to all(be(true))
  end
end
