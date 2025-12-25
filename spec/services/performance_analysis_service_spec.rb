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
      subject { described_class.call(analysis_type: :unknown) }

      it "returns an error" do
        expect(subject).to eq({ error: "Unknown analysis type: unknown" })
      end
    end
  end

  describe "gaps analysis" do
    subject { described_class.call(analysis_type: :gaps, filters: filters) }

    let(:filters) { { min_gap: 5 } }

    let!(:show1) { create(:show, date: "2023-01-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show3) { create(:show, date: "2023-12-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [original_song])
      create(:track, show: show3, position: 1, set: "1", songs: [original_song2])
      (1..10).each do |i|
        show = create(:show, date: "2023-06-#{(i + 10).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show: show, position: 1, set: "1", songs: [original_song2])
      end
    end

    it "returns songs with gaps above minimum" do
      expect(subject[:songs]).to be_an(Array)
      tweezer_result = subject[:songs].find { |s| s[:song] == "Tweezer" }
      expect(tweezer_result).to be_present
      expect(tweezer_result[:gap]).to be >= 5
    end

    it "includes latest show date" do
      expect(subject[:latest_show_date]).to be_present
    end

    it "sorts by gap descending" do
      gaps = subject[:songs].map { |s| s[:gap] }
      expect(gaps).to eq(gaps.sort.reverse)
    end
  end

  describe "transitions analysis" do
    subject { described_class.call(analysis_type: :transitions, filters: filters) }

    let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show:, position: 1, set: "1", songs: [original_song])
      create(:track, show:, position: 2, set: "1", songs: [original_song2])
      create(:track, show:, position: 3, set: "1", songs: [cover_song])
    end

    context "with song_slug filter" do
      let(:filters) { { song_slug: original_song.slug, direction: "after" } }

      it "returns transitions for the specified song" do
        expect(subject[:song]).to eq("Tweezer")
        expect(subject[:direction]).to eq("after")
        expect(subject[:transitions]).to be_an(Array)
      end

      it "finds the correct following song" do
        yem_transition = subject[:transitions].find { |t| t[:song] == "You Enjoy Myself" }
        expect(yem_transition).to be_present
        expect(yem_transition[:count]).to eq(1)
      end
    end

    context "with direction before" do
      let(:filters) { { song_slug: original_song2.slug, direction: "before" } }

      it "returns preceding songs" do
        expect(subject[:direction]).to eq("before")
        tweezer_transition = subject[:transitions].find { |t| t[:song] == "Tweezer" }
        expect(tweezer_transition).to be_present
      end
    end

    context "without song_slug (common transitions)" do
      let(:filters) { {} }

      it "returns common song pairings" do
        expect(subject[:transitions]).to be_an(Array)
      end
    end

    context "with non-existent song" do
      let(:filters) { { song_slug: "nonexistent-song" } }

      it "returns an error" do
        expect(subject[:error]).to eq("Song not found")
      end
    end
  end

  describe "durations analysis" do
    subject { described_class.call(analysis_type: :durations, filters: filters) }

    let!(:show1) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show2) { create(:show, date: "2023-07-02", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [original_song], duration: 900_000)
      create(:track, show: show2, position: 1, set: "2", songs: [original_song], duration: 1_200_000)
      create(:track, show: show1, position: 2, set: "1", songs: [original_song2], duration: 600_000)
    end

    context "with song_slug filter" do
      let(:filters) { { song_slug: original_song.slug } }

      it "returns duration data for the specified song" do
        expect(subject[:song]).to eq("Tweezer")
        expect(subject[:performances]).to be_an(Array)
        expect(subject[:performances].length).to eq(2)
      end

      it "returns average duration" do
        expect(subject[:average_duration_ms]).to eq(1_050_000)
      end

      it "sorts by duration descending" do
        durations = subject[:performances].map { |p| p[:duration_ms] }
        expect(durations).to eq(durations.sort.reverse)
      end

      it "includes formatted duration display" do
        expect(subject[:performances].first[:duration_display]).to eq("20:00")
      end
    end

    context "without song_slug (longest songs)" do
      let(:filters) { { min_performances: 1 } }

      it "returns songs sorted by average duration" do
        expect(subject[:songs]).to be_an(Array)
        first_song = subject[:songs].first
        expect(first_song).to include(:avg_duration_ms, :max_duration_ms)
      end
    end

    context "with non-existent song" do
      let(:filters) { { song_slug: "nonexistent-song" } }

      it "returns an error" do
        expect(subject[:error]).to eq("Song not found")
      end
    end
  end

  describe "venue_patterns analysis" do
    subject { described_class.call(analysis_type: :venue_patterns, filters: filters) }

    let!(:show1) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show2) { create(:show, date: "2023-07-02", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show3) { create(:show, date: "2023-07-03", venue: venue2, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [original_song])
      create(:track, show: show2, position: 1, set: "1", songs: [original_song])
      create(:track, show: show3, position: 1, set: "1", songs: [original_song2])
    end

    context "with venue_slug filter" do
      let(:filters) { { venue_slug: venue.slug } }

      it "returns venue-specific song data" do
        expect(subject[:venue]).to eq(venue.name)
        expect(subject[:show_count]).to eq(2)
        expect(subject[:top_songs]).to be_an(Array)
      end

      it "shows most played songs at venue" do
        tweezer = subject[:top_songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:count]).to eq(2)
      end
    end

    context "without venue_slug (venue rankings)" do
      let(:filters) { {} }

      it "returns venues sorted by show count" do
        expect(subject[:venues]).to be_an(Array)
        expect(subject[:venues].first).to include(:venue, :show_count)
      end
    end

    context "with non-existent venue" do
      let(:filters) { { venue_slug: "nonexistent-venue" } }

      it "returns an error" do
        expect(subject[:error]).to eq("Venue not found")
      end
    end
  end

  describe "set_positions analysis" do
    subject { described_class.call(analysis_type: :set_positions, filters: filters) }

    let!(:show1) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }
    let!(:show2) { create(:show, date: "2023-07-02", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show1, position: 1, set: "1", songs: [original_song])
      create(:track, show: show1, position: 2, set: "1", songs: [original_song2])
      create(:track, show: show1, position: 3, set: "2", songs: [cover_song])
      create(:track, show: show1, position: 4, set: "2", songs: [original_song])
      create(:track, show: show1, position: 5, set: "E", songs: [cover_song2])

      create(:track, show: show2, position: 1, set: "1", songs: [original_song])
      create(:track, show: show2, position: 2, set: "2", songs: [original_song2])
      create(:track, show: show2, position: 3, set: "E", songs: [cover_song2])
    end

    context "with position opener" do
      let(:filters) { { position: "opener" } }

      it "returns set 1 openers" do
        expect(subject[:position]).to eq("opener")
        expect(subject[:set]).to eq("Set 1")
        tweezer = subject[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:count]).to eq(2)
      end

      it "includes percentage" do
        expect(subject[:songs].first[:percentage]).to be_a(Numeric)
      end
    end

    context "with position closer" do
      let(:filters) { { position: "closer", set: "2" } }

      it "returns set closers" do
        expect(subject[:position]).to eq("closer")
        tweezer = subject[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:count]).to eq(1)
      end
    end

    context "with position encore" do
      let(:filters) { { position: "encore" } }

      it "returns encore songs" do
        expect(subject[:position]).to eq("encore")
        cities = subject[:songs].find { |s| s[:song] == "Cities" }
        expect(cities[:count]).to eq(2)
      end
    end

    context "with song_slug (distribution)" do
      let(:filters) { { song_slug: original_song.slug } }

      it "returns position distribution for song" do
        expect(subject[:song]).to eq("Tweezer")
        expect(subject[:total_performances]).to eq(3)
        expect(subject[:by_set]).to be_an(Array)
        expect(subject[:opener_count]).to eq(2)
        expect(subject[:closer_count]).to be >= 1
      end
    end
  end

  describe "predictions analysis" do
    subject { described_class.call(analysis_type: :predictions, filters: filters) }

    let(:filters) { { limit: 10 } }

    before do
      20.times do |i|
        show = create(:show, date: "2023-01-#{(i + 1).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [original_song])
        create(:track, show:, position: 2, set: "1", songs: [original_song2]) if i < 15
      end
    end

    it "returns predictions with scores" do
      expect(subject[:predictions]).to be_an(Array)
      expect(subject[:predictions].first).to include(:song, :score, :current_gap, :avg_gap)
    end

    it "includes gap ratio for songs with sufficient plays" do
      prediction = subject[:predictions].first
      expect(prediction[:gap_ratio]).to be_a(Numeric)
    end

    it "sorts by score descending" do
      scores = subject[:predictions].map { |p| p[:score] }
      expect(scores).to eq(scores.sort.reverse)
    end
  end

  describe "streaks analysis" do
    subject { described_class.call(analysis_type: :streaks, filters: filters) }

    before do
      10.times do |i|
        show = create(:show, date: "2023-07-#{(i + 1).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [original_song])
        create(:track, show:, position: 2, set: "1", songs: [original_song2]) if i < 5
      end
    end

    context "with song_slug" do
      let(:filters) { { song_slug: original_song.slug } }

      it "returns streak data for song" do
        expect(subject[:song]).to eq("Tweezer")
        expect(subject[:current_streak]).to eq(10)
        expect(subject[:longest_streak]).to eq(10)
      end
    end

    context "without song_slug (active streaks)" do
      let(:filters) { {} }

      it "returns songs with active streaks" do
        expect(subject[:streaks]).to be_an(Array)
        tweezer = subject[:streaks].find { |s| s[:song] == "Tweezer" }
        expect(tweezer[:current_streak]).to eq(10)
      end
    end

    context "with non-existent song" do
      let(:filters) { { song_slug: "nonexistent-song" } }

      it "returns an error" do
        expect(subject[:error]).to eq("Song not found")
      end
    end
  end

  describe "era_comparison analysis" do
    subject { described_class.call(analysis_type: :era_comparison, filters: filters) }

    before do
      5.times do |i|
        show = create(:show, date: "1997-07-#{(i + 1).to_s.rjust(2, '0')}", venue:, tour:, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [original_song], duration: 1_200_000)
        create(:track, show:, position: 2, set: "1", songs: [cover_song], duration: 600_000)
      end

      5.times do |i|
        show = create(:show, date: "2023-09-#{(i + 1).to_s.rjust(2, '0')}", venue:, tour: tour2, performance_gap_value: 1)
        create(:track, show:, position: 1, set: "1", songs: [original_song], duration: 900_000)
        create(:track, show:, position: 2, set: "1", songs: [original_song2], duration: 800_000)
      end
    end

    context "with valid eras" do
      let(:filters) { { year: 1997, compare_to: { year: 2023 } } }

      it "returns stats for both eras" do
        expect(subject[:era1][:era]).to eq("1997")
        expect(subject[:era2][:era]).to eq("2023")
      end

      it "includes show counts" do
        expect(subject[:era1][:show_count]).to eq(5)
        expect(subject[:era2][:show_count]).to eq(5)
      end

      it "calculates cover percentages" do
        expect(subject[:era1][:cover_pct]).to be > 0
        expect(subject[:era2][:original_pct]).to be >= subject[:era1][:original_pct]
      end

      it "includes comparison data" do
        expect(subject[:comparison]).to include(:show_count_diff, :avg_duration_diff_ms)
      end
    end

    context "with year ranges" do
      let(:filters) { { year_range: [1995, 1999], compare_to: { year_range: [2020, 2025] } } }

      it "handles year ranges" do
        expect(subject[:era1][:era]).to eq("1995-1999")
        expect(subject[:era2][:era]).to eq("2020-2025")
      end
    end

    context "without compare_to" do
      let(:filters) { { year: 1997 } }

      it "returns an error" do
        expect(subject[:error]).to eq("Both era and compare_to required")
      end
    end
  end

  describe "covers analysis" do
    subject { described_class.call(analysis_type: :covers, filters: filters) }

    before do
      show = create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1)
      create(:track, show:, position: 1, set: "1", songs: [cover_song])
      create(:track, show:, position: 2, set: "1", songs: [cover_song2])
      create(:track, show:, position: 3, set: "1", songs: [original_song])

      show2 = create(:show, date: "2023-07-02", venue:, tour: tour2, performance_gap_value: 1)
      create(:track, show: show2, position: 1, set: "1", songs: [cover_song])
    end

    context "with cover_type frequency" do
      let(:filters) { { cover_type: "frequency" } }

      it "returns covers sorted by frequency" do
        expect(subject[:covers]).to be_an(Array)
        cap = subject[:covers].find { |c| c[:song] == "Crosseyed and Painless" }
        expect(cap[:count]).to eq(2)
        expect(cap[:artist]).to eq("Talking Heads")
      end
    end

    context "with cover_type ratio" do
      let(:filters) { { cover_type: "ratio" } }

      it "returns cover ratio by year" do
        expect(subject[:by_year]).to be_an(Array)
        year_2023 = subject[:by_year].find { |y| y[:year] == 2023 }
        expect(year_2023[:cover_pct]).to be > 0
      end
    end

    context "with cover_type by_artist" do
      let(:filters) { { cover_type: "by_artist" } }

      it "returns covers grouped by artist" do
        expect(subject[:artists]).to be_an(Array)
        talking_heads = subject[:artists].find { |a| a[:artist] == "Talking Heads" }
        expect(talking_heads[:count]).to eq(3)
      end
    end
  end

  describe "geographic analysis" do
    subject { described_class.call(analysis_type: :geographic, filters: filters) }

    before do
      show_ny = create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1)
      create(:track, show: show_ny, position: 1, set: "1", songs: [original_song])
      create(:track, show: show_ny, position: 2, set: "1", songs: [cover_song])

      show_ca = create(:show, date: "2023-07-02", venue: venue2, tour: tour2, performance_gap_value: 1)
      create(:track, show: show_ca, position: 1, set: "1", songs: [original_song2])
    end

    context "with geo_type state_frequency" do
      let(:filters) { { geo_type: "state_frequency" } }

      it "returns show counts by state" do
        expect(subject[:states]).to be_an(Array)
        ny = subject[:states].find { |s| s[:state] == "NY" }
        ca = subject[:states].find { |s| s[:state] == "CA" }
        expect(ny[:show_count]).to eq(1)
        expect(ca[:show_count]).to eq(1)
      end
    end

    context "with geo_type never_played" do
      let(:filters) { { geo_type: "never_played", state: "CA" } }

      it "returns songs never played in state" do
        expect(subject[:state]).to eq("CA")
        expect(subject[:never_played_songs]).to be_an(Array)
      end
    end

    context "with geo_type state_debuts" do
      let(:filters) { { geo_type: "state_debuts", state: "NY" } }

      it "returns state debut songs" do
        expect(subject[:state]).to eq("NY")
        expect(subject[:debuts]).to be_an(Array)
        expect(subject[:debuts].first).to include(:song, :date, :venue)
      end
    end

    context "without required state" do
      let(:filters) { { geo_type: "never_played" } }

      it "returns an error" do
        expect(subject[:error]).to eq("state required")
      end
    end
  end

  describe "filtering" do
    let!(:show_1997) { create(:show, date: "1997-07-01", venue:, tour:, performance_gap_value: 1) }
    let!(:show_2023) { create(:show, date: "2023-09-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show: show_1997, position: 1, set: "1", songs: [original_song], duration: 1_200_000)
      create(:track, show: show_2023, position: 1, set: "1", songs: [original_song], duration: 900_000)
    end

    context "with year filter" do
      subject { described_class.call(analysis_type: :durations, filters: { song_slug: original_song.slug, year: 1997 }) }

      it "filters by year" do
        expect(subject[:performances].length).to eq(1)
        expect(subject[:performances].first[:date]).to start_with("1997")
      end
    end

    context "with year_range filter" do
      subject { described_class.call(analysis_type: :durations, filters: { song_slug: original_song.slug, year_range: [2020, 2025] }) }

      it "filters by year range" do
        expect(subject[:performances].length).to eq(1)
        expect(subject[:performances].first[:date]).to start_with("2023")
      end
    end

    context "with tour_slug filter" do
      subject { described_class.call(analysis_type: :durations, filters: { song_slug: original_song.slug, tour_slug: tour.slug }) }

      it "filters by tour" do
        expect(subject[:performances].length).to eq(1)
      end
    end
  end

  describe "edge cases" do
    context "with no data" do
      subject { described_class.call(analysis_type: :gaps, filters: { min_gap: 1000 }) }

      it "handles empty results gracefully" do
        expect(subject[:songs]).to eq([])
      end
    end

    context "with soundcheck tracks" do
      let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

      before do
        create(:track, show:, position: 1, set: "S", songs: [original_song])
        create(:track, show:, position: 2, set: "1", songs: [original_song2])
      end

      subject { described_class.call(analysis_type: :set_positions, filters: { position: "opener" }) }

      it "excludes soundcheck tracks" do
        tweezer = subject[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer).to be_nil
      end
    end

    context "with excluded tracks" do
      let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

      before do
        create(:track, show:, position: 1, set: "1", songs: [original_song], exclude_from_stats: true)
        create(:track, show:, position: 2, set: "1", songs: [original_song2])
      end

      subject { described_class.call(analysis_type: :set_positions, filters: { position: "opener" }) }

      it "excludes tracks marked exclude_from_stats" do
        tweezer = subject[:songs].find { |s| s[:song] == "Tweezer" }
        expect(tweezer).to be_nil
      end
    end
  end

  describe "logging" do
    let!(:show) { create(:show, date: "2023-07-01", venue:, tour: tour2, performance_gap_value: 1) }

    before do
      create(:track, show:, position: 1, set: "1", songs: [original_song])
    end

    context "when log_call is true" do
      subject do
        described_class.call(
          analysis_type: :gaps,
          filters: { min_gap: 1 },
          log_call: true
        )
      end

      it "logs the call to McpToolCall" do
        expect { subject }.to change(McpToolCall, :count).by(1)
      end

      it "records parameters including analysis_type" do
        subject
        log = McpToolCall.last
        expect(log.parameters["analysis_type"]).to eq("gaps")
        expect(log.parameters["min_gap"]).to eq(1)
      end

      it "records duration" do
        subject
        log = McpToolCall.last
        expect(log.duration_ms).to be_a(Integer)
        expect(log.duration_ms).to be >= 0
      end
    end

    context "when log_call is false" do
      subject do
        described_class.call(
          analysis_type: :gaps,
          filters: { min_gap: 1 },
          log_call: false
        )
      end

      it "does not log the call" do
        expect { subject }.not_to change(McpToolCall, :count)
      end
    end

  end

  describe "#format_duration" do
    subject { described_class.new(analysis_type: :durations).send(:format_duration, ms) }

    context "with nil" do
      let(:ms) { nil }

      it { is_expected.to eq("0:00") }
    end

    context "with 0" do
      let(:ms) { 0 }

      it { is_expected.to eq("0:00") }
    end

    context "with 90 seconds" do
      let(:ms) { 90_000 }

      it { is_expected.to eq("1:30") }
    end

    context "with 20 minutes" do
      let(:ms) { 1_200_000 }

      it { is_expected.to eq("20:00") }
    end

    context "with 5 seconds" do
      let(:ms) { 5_000 }

      it { is_expected.to eq("0:05") }
    end
  end
end

