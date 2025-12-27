require "rails_helper"

RSpec.describe PerformanceAnalysisService do
  let!(:venue) { create(:venue, state: "NY", country: "USA") }
  let!(:venue2) { create(:venue, state: "CA", country: "USA") }
  let!(:tour) { create(:tour, name: "Summer 1997", starts_on: "1997-06-01", ends_on: "1997-08-31") }
  let!(:tour2) { create(:tour, name: "Fall 2023", starts_on: "2023-09-01", ends_on: "2023-11-30") }

  let!(:original_song) { create(:song, title: "Tweezer", original: true) }
  let!(:original_song2) { create(:song, title: "You Enjoy Myself", original: true) }
  let!(:cover_song) { create(:song, title: "Crosseyed and Painless", original: false, artist: "Talking Heads") }
  let!(:cover_song2) { create(:song, title: "Cities", original: false, artist: "Talking Heads") }

  describe "#call" do
    context "with unknown analysis type" do
      subject(:result) { described_class.call(analysis_type: :unknown) }

      it "returns an error" do
        expect(result).to eq({ error: "Unknown analysis type: unknown" })
      end
    end
  end

  describe "gaps analysis" do
    subject(:result) { described_class.call(analysis_type: :gaps, filters:) }

    let(:filters) { { min_gap: 5 } }

    let!(:show1) { create(:show, date: "2023-01-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show3) { create(:show, date: "2023-12-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show3, position: 1, set: "1", songs: [ original_song2 ])
      (1..10).each do |i|
        show = create(:show, date: "2023-06-#{(i + 10).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [ original_song2 ])
      end
    end

    it "returns songs with gaps above minimum, sorted descending", :aggregate_failures do
      expect(result[:songs]).to be_an(Array)
      expect(result[:latest_show_date]).to be_present
      tweezer_result = result[:songs].find { |s| s[:song] == "Tweezer" }
      expect(tweezer_result[:gap]).to be >= 5
    end
  end

  describe "transitions analysis" do
    subject(:result) { described_class.call(analysis_type: :transitions, filters:) }

    let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show:, position: 1, set: "1", songs: [ original_song ])
      create(:track, show:, position: 2, set: "1", songs: [ original_song2 ])
      create(:track, show:, position: 3, set: "1", songs: [ cover_song ])
    end

    context "with song_slug filter" do
      let(:filters) { { song_slug: original_song.slug, direction: "after" } }

      it "returns transitions for the specified song", :aggregate_failures do
        expect(result).to include(song: "Tweezer", direction: "after")
        expect(result[:transitions]).to be_an(Array)
        yem_transition = result[:transitions].find { |t| t[:song] == "You Enjoy Myself" }
        expect(yem_transition[:count]).to eq(1)
      end
    end

    context "with direction before" do
      let(:filters) { { song_slug: original_song2.slug, direction: "before" } }

      it "returns preceding songs" do
        expect(result[:direction]).to eq("before")
        tweezer_transition = result[:transitions].find { |t| t[:song] == "Tweezer" }
        expect(tweezer_transition).to be_present
      end
    end

    context "without song_slug (common transitions)" do
      let(:filters) { {} }

      it "returns common song pairings" do
        expect(result[:transitions]).to be_an(Array)
      end
    end

    context "with non-existent song" do
      let(:filters) { { song_slug: "nonexistent-song" } }

      it "returns an error" do
        expect(result[:error]).to eq("Song not found")
      end
    end
  end

  describe "set_positions analysis" do
    subject(:result) { described_class.call(analysis_type: :set_positions, filters:) }

    let!(:show1) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show2) { create(:show, date: "2023-07-02", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show1, position: 2, set: "1", songs: [ original_song2 ])
      create(:track, show: show1, position: 3, set: "2", songs: [ cover_song ])
      create(:track, show: show1, position: 4, set: "2", songs: [ original_song ])
      create(:track, show: show1, position: 5, set: "E", songs: [ cover_song2 ])
      create(:track, show: show2, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show2, position: 2, set: "2", songs: [ original_song2 ])
      create(:track, show: show2, position: 3, set: "E", songs: [ cover_song2 ])
    end

    context "with position opener" do
      let(:filters) { { position: "opener" } }

      it "returns set 1 openers with percentage" do
        expect(result[:position]).to eq("opener")
        expect(result[:set]).to eq("Set 1")
        tweezer = result[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:count]).to eq(2)
        expect(result[:songs].first[:percentage]).to be_a(Numeric)
      end
    end

    context "with position closer" do
      let(:filters) { { position: "closer", set: "2" } }

      it "returns set closers" do
        expect(result[:position]).to eq("closer")
        tweezer = result[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:count]).to eq(1)
      end
    end

    context "with position encore" do
      let(:filters) { { position: "encore" } }

      it "returns encore songs" do
        expect(result[:position]).to eq("encore")
        cities = result[:songs].find { |s| s[:song] == "Cities" }
        expect(cities[:count]).to eq(2)
      end
    end

    context "with song_slug (distribution)" do
      let(:filters) { { song_slug: original_song.slug } }

      it "returns position distribution for song", :aggregate_failures do
        expect(result[:song]).to eq("Tweezer")
        expect(result[:total_performances]).to eq(3)
        expect(result[:by_set]).to be_an(Array)
        expect(result[:opener_count]).to eq(2)
        expect(result[:closer_count]).to be >= 1
      end
    end
  end

  describe "predictions analysis" do
    subject(:result) { described_class.call(analysis_type: :predictions, filters:) }

    let(:filters) { { limit: 10 } }

    before do
      20.times do |i|
        show = create(:show, date: "2023-01-#{(i + 1).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [ original_song ])
        create(:track, show:, position: 2, set: "1", songs: [ original_song2 ]) if i < 15
      end
    end

    it "returns predictions with scores and gap ratio", :aggregate_failures do
      expect(result[:predictions]).to be_an(Array)
      expect(result[:predictions].first).to include(:song, :score, :current_gap, :avg_gap)
      expect(result[:predictions].first[:gap_ratio]).to be_a(Numeric)
    end
  end

  describe "streaks analysis" do
    subject(:result) { described_class.call(analysis_type: :streaks, filters:) }

    before do
      10.times do |i|
        show = create(:show, date: "2023-07-#{(i + 1).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [ original_song ])
        create(:track, show:, position: 2, set: "1", songs: [ original_song2 ]) if i < 5
      end
    end

    context "with song_slug" do
      let(:filters) { { song_slug: original_song.slug } }

      it "returns streak data for song" do
        expect(result[:song]).to eq("Tweezer")
        expect(result[:current_streak]).to eq(10)
        expect(result[:longest_streak]).to eq(10)
      end
    end

    context "without song_slug (active streaks)" do
      let(:filters) { {} }

      it "returns songs with active streaks" do
        expect(result[:streaks]).to be_an(Array)
        tweezer = result[:streaks].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:current_streak]).to eq(10)
      end
    end

    context "with non-existent song" do
      let(:filters) { { song_slug: "nonexistent-song" } }

      it "returns an error" do
        expect(result[:error]).to eq("Song not found")
      end
    end
  end

  describe "geographic analysis" do
    subject(:result) { described_class.call(analysis_type: :geographic, filters:) }

    before do
      show_ny = create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1)
      create(:track, show: show_ny, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show_ny, position: 2, set: "1", songs: [ cover_song ])

      show_ca = create(:show, date: "2023-07-02", venue: venue2, tour: tour2, performance_gap_value: 1)
      create(:track, show: show_ca, position: 1, set: "1", songs: [ original_song2 ])
    end

    context "with geo_type state_frequency" do
      let(:filters) { { geo_type: "state_frequency" } }

      it "returns show counts by state" do
        expect(result[:states]).to be_an(Array)
        ny = result[:states].find { |s| s[:state] == "NY" }
        ca = result[:states].find { |s| s[:state] == "CA" }
        expect(ny[:show_count]).to eq(1)
        expect(ca[:show_count]).to eq(1)
      end
    end

    context "with geo_type never_played" do
      let(:filters) { { geo_type: "never_played", state: "CA" } }

      it "returns songs never played in state" do
        expect(result[:state]).to eq("CA")
        expect(result[:never_played_songs]).to be_an(Array)
      end
    end

    context "with geo_type state_debuts" do
      let(:filters) { { geo_type: "state_debuts", state: "NY" } }

      it "returns state debut songs" do
        expect(result[:state]).to eq("NY")
        expect(result[:debuts]).to be_an(Array)
        expect(result[:debuts].first).to include(:song, :date, :venue)
      end
    end

    context "without required state" do
      let(:filters) { { geo_type: "never_played" } }

      it "returns an error" do
        expect(result[:error]).to eq("state required")
      end
    end
  end

  describe "song_frequency analysis" do
    subject(:result) { described_class.call(analysis_type: :song_frequency, filters:) }

    let!(:show1) { create(:show, date: "2003-07-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show2) { create(:show, date: "2003-07-02", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show3) { create(:show, date: "2003-07-03", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show1, position: 2, set: "1", songs: [ original_song2 ])
      create(:track, show: show2, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show2, position: 2, set: "1", songs: [ original_song ])
      create(:track, show: show3, position: 1, set: "1", songs: [ original_song2 ])
    end

    context "without filters" do
      let(:filters) { {} }

      it "returns songs ranked by play count", :aggregate_failures do
        expect(result[:songs].first[:song]).to eq("Tweezer")
        expect(result[:songs].find { |s| s[:song] == "Tweezer" }[:times_played]).to eq(3)
        expect(result[:songs].find { |s| s[:song] == "You Enjoy Myself" }[:times_played]).to eq(2)
        expect(result[:filter]).to eq("all time")
      end
    end

    context "with year filter" do
      let(:filters) { { year: 2003 } }

      it "filters by year and includes filter description", :aggregate_failures do
        expect(result[:songs]).to be_an(Array)
        expect(result[:filter]).to eq("year: 2003")
      end
    end

    context "with year_range filter" do
      let(:filters) { { year_range: [ 2002, 2004 ] } }

      it "filters by year range", :aggregate_failures do
        expect(result[:songs]).to be_an(Array)
        expect(result[:filter]).to eq("years: 2002-2004")
      end
    end
  end

  describe "filtering" do
    let!(:show_1997) { create(:show, date: "1997-07-01", venue:, tour:, performance_gap_value: 1) }
    let!(:show_2023) { create(:show, date: "2023-09-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show_1997, position: 1, set: "1", songs: [ original_song ])
      create(:track, show: show_2023, position: 1, set: "1", songs: [ original_song2 ])
    end

    context "with year filter" do
      subject(:result) { described_class.call(analysis_type: :song_frequency, filters: { year: 1997 }) }

      it "filters by year" do
        expect(result[:songs].length).to eq(1)
        expect(result[:songs].first[:song]).to eq("Tweezer")
      end
    end

    context "with year_range filter" do
      subject(:result) { described_class.call(analysis_type: :song_frequency, filters: { year_range: [ 2020, 2025 ] }) }

      it "filters by year range" do
        expect(result[:songs].length).to eq(1)
        expect(result[:songs].first[:song]).to eq("You Enjoy Myself")
      end
    end

    context "with tour_slug filter" do
      subject(:result) { described_class.call(analysis_type: :song_frequency, filters: { tour_slug: tour.slug }) }

      it "filters by tour" do
        expect(result[:songs].length).to eq(1)
        expect(result[:songs].first[:song]).to eq("Tweezer")
      end
    end
  end

  describe "edge cases" do
    context "with no data" do
      subject(:result) { described_class.call(analysis_type: :gaps, filters: { min_gap: 1000 }) }

      it "handles empty results gracefully" do
        expect(result[:songs]).to eq([])
      end
    end

    context "with soundcheck tracks" do
      subject(:result) { described_class.call(analysis_type: :set_positions, filters: { position: "opener" }) }

      let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

      before do
        create(:track, show:, position: 1, set: "S", songs: [ original_song ])
        create(:track, show:, position: 2, set: "1", songs: [ original_song2 ])
      end

      it "excludes soundcheck tracks" do
        tweezer = result[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer).to be_nil
      end
    end

    context "with excluded tracks" do
      subject(:result) { described_class.call(analysis_type: :set_positions, filters: { position: "opener" }) }

      let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

      before do
        create(:track, show:, position: 1, set: "1", songs: [ original_song ], exclude_from_stats: true)
        create(:track, show:, position: 2, set: "1", songs: [ original_song2 ])
      end

      it "excludes tracks marked exclude_from_stats" do
        tweezer = result[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer).to be_nil
      end
    end
  end

  describe "logging" do
    let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show:, position: 1, set: "1", songs: [ original_song ])
    end

    context "when log_call is true" do
      subject(:result) { described_class.call(analysis_type: :gaps, filters: { min_gap: 1 }, log_call: true) }

      it "logs the call with parameters and duration" do
        expect { result }.to change(McpToolCall, :count).by(1)
        log = McpToolCall.last
        expect(log.parameters).to include("analysis_type" => "gaps", "min_gap" => 1)
        expect(log.duration_ms).to be_a(Integer)
        expect(log.duration_ms).to be >= 0
      end
    end

    context "when log_call is false" do
      subject(:result) { described_class.call(analysis_type: :gaps, filters: { min_gap: 1 }, log_call: false) }

      it "does not log the call" do
        expect { result }.not_to change(McpToolCall, :count)
      end
    end
  end
end
