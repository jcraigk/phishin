require "rails_helper"

RSpec.describe GapService do
  subject(:service) { described_class.new(current_show).call }

  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:known_dates) do
    [
      create(:known_date, date: "2022-12-29"),
      create(:known_date, date: "2022-12-30"),
      create(:known_date, date: "2023-01-01"),
      create(:known_date, date: "2023-01-03"),
      create(:known_date, date: "2023-01-04"),
      create(:known_date, date: "2023-01-05")
    ]
  end
  let!(:previous_show) { create(:show, date: "2022-12-30", venue:) }
  let!(:next_show) { create(:show, date: "2023-01-05", venue:) }
  let!(:current_show) { create(:show, date: "2023-01-01", venue:) }
  let!(:song) { create(:song, title: "Tweezer") }
  let!(:tracks) do
    [
      create(:track, show: current_show, position: 1, songs: [song]),
      create(:track, show: current_show, position: 5, songs: [song]),
      create(:track, show: current_show, position: 10, songs: [song]),
      create(:track, show: previous_show, position: 1, songs: [song]),
      create(:track, show: next_show, position: 1, songs: [song])
    ]
  end

  before { service }

  it "updates the gaps and slugs for song performances" do
    first_song_track = SongsTrack.find_by(track_id: tracks[0].id, song_id: song.id)
    expect(first_song_track.previous_performance_gap).to eq(1)
    expect(first_song_track.previous_performance_slug).to eq("2022-12-30/#{tracks[3].slug}")

    second_song_track = SongsTrack.find_by(track_id: tracks[1].id, song_id: song.id)
    expect(second_song_track.previous_performance_gap).to eq(0)
    expect(second_song_track.previous_performance_slug).to eq("2023-01-01/#{tracks[0].slug}")

    third_song_track = SongsTrack.find_by(track_id: tracks[2].id, song_id: song.id)
    expect(third_song_track.previous_performance_gap).to eq(0)
    expect(third_song_track.previous_performance_slug).to eq("2023-01-01/#{tracks[1].slug}")

    expect(first_song_track.next_performance_gap).to eq(0)
    expect(first_song_track.next_performance_slug).to eq("2023-01-01/#{tracks[1].slug}")

    expect(third_song_track.next_performance_gap).to eq(3)
    expect(third_song_track.next_performance_slug).to eq("2023-01-05/#{tracks[4].slug}")
  end
end
