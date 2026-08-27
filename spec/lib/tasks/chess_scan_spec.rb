require "rails_helper"
require "rake"

RSpec.describe "chess_scan" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("chess_scan:run")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/split_scan.rake")
    load Rails.root.join("lib/tasks/chess_scan.rake")
  end

  let!(:chess_song) { create(:song, title: "Audience Chess Move") }
  let(:song) { create(:song, title: "Reba") }
  let(:track) { create(:track, title: "Reba", songs: [ song ], duration: 600_000) }

  describe ".plan" do
    it "finds the chess part by its song and keeps the export's order" do
      entry = { "cut_points" => [ 18.7 ], "part_titles" => [ "Audience Chess Move", "Reba" ],
                "song_ids" => [ chess_song.id, song.id ] }
      plan = ChessScan.plan(entry, track)
      expect(plan).to include(
        cut_points: [ 18.7 ],
        part_titles: [ "Audience Chess Move", "Reba" ],
        song_ids: [ chess_song.id, song.id ],
        chess_index: 0
      )
    end

    it "accepts the chess part after the song and fills a missing song id from the track" do
      entry = { "cut_points" => [ 570.8 ], "part_titles" => [ "Reba", "Band Chess Move" ],
                "song_ids" => [ nil, chess_song.id ] }
      plan = ChessScan.plan(entry, track)
      expect(plan).to include(
        part_titles: [ "Reba", "Band Chess Move" ],
        song_ids: [ song.id, chess_song.id ],
        chess_index: 1
      )
    end

    it "keeps recording-wide tags on both parts and song tags on the song part" do
      sbd = create(:tag, name: "SBD")
      tease = create(:tag, name: "Tease")
      track.track_tags.create!(tag: sbd)
      track.track_tags.create!(tag: tease, notes: "Antelope")
      entry = { "cut_points" => [ 18.7 ], "part_titles" => [ "Audience Chess Move", "Reba" ],
                "song_ids" => [ chess_song.id, song.id ] }
      expect(ChessScan.plan(entry, track)[:tag_sides]).to eq("SBD" => [ 0, 1 ], "Tease" => [ 1 ])
    end

    it "lets the reviewer's tag sides win" do
      tease = create(:tag, name: "Tease")
      track.track_tags.create!(tag: tease)
      entry = { "cut_points" => [ 18.7 ], "part_titles" => [ "Audience Chess Move", "Reba" ],
                "song_ids" => [ chess_song.id, song.id ], "tag_sides" => { "Tease" => [ 0 ] } }
      expect(ChessScan.plan(entry, track)[:tag_sides]).to eq("Tease" => [ 0 ])
    end

    it "raises when neither part is the chess move" do
      entry = { "cut_points" => [ 1.0 ], "part_titles" => [ "Reba", "Rift" ],
                "song_ids" => [ song.id, song.id ] }
      expect { ChessScan.plan(entry, track) }.to raise_error(ChessScan::Error, /neither part/)
    end
  end

  describe ".relink" do
    let(:banter_song) { create(:song, title: "Banter") }

    it "retitles chess tracks linked to the generic Banter song and links the chess song" do
      show = create(:show, date: "1995-11-12")
      stray = create(:track, show:, title: "Chess Move", songs: [ banter_song ])
      fine = create(:track, show:, title: "Audience Chess Move", songs: [ chess_song ])
      other = create(:track, show:, title: "Banter", songs: [ banter_song ])

      changed = ChessScan.relink(Track.where(show:))

      expect(changed.map(&:id)).to eq([ stray.id ])
      expect(stray.reload.title).to eq("Audience Chess Move")
      expect(stray.songs).to eq([ chess_song ])
      expect(fine.reload.songs).to eq([ chess_song ])
      expect(other.reload.songs).to eq([ banter_song ])
    end
  end
end
