class PerformanceAnalysisService < ApplicationService
  option :analysis_type
  option :filters, default: -> { {} }
  option :log_call, default: -> { false }

  SET_NAMES = {
    "1" => "Set 1",
    "2" => "Set 2",
    "3" => "Set 3",
    "E" => "Encore",
    "E2" => "Encore 2",
    "P" => "Pre-show"
  }.freeze

  MAIN_SETS = %w[1 2 3 E E2].freeze
  EXCLUDED_SETS = %w[S P].freeze

  def call
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = case analysis_type.to_sym
    when :gaps then analyze_gaps
    when :transitions then analyze_transitions
    when :set_positions then analyze_set_positions
    when :predictions then analyze_predictions
    when :streaks then analyze_streaks
    when :geographic then analyze_geographic
    when :co_occurrence then analyze_co_occurrence
    when :song_frequency then analyze_song_frequency
    else
      { error: "Unknown analysis type: #{analysis_type}" }
    end

    log_mcp_call(result, start_time) if log_call

    result
  end

  private

  def limit
    filters[:limit] || 25
  end

  def base_tracks
    scope = Track.joins(:show, :songs)
                 .where.not(tracks: { set: EXCLUDED_SETS })
                 .where(tracks: { exclude_from_stats: false })
                 .where("shows.performance_gap_value > 0")
    apply_filters(scope)
  end

  def apply_filters(scope)
    scope = apply_date_filters(scope)
    scope = apply_tour_filter(scope)
    scope = apply_song_filter(scope)
    scope = apply_venue_filter(scope)
    scope = apply_state_filter(scope)
    scope
  end

  def apply_date_filters(scope)
    if filters[:year]
      scope.where("EXTRACT(year FROM shows.date) = ?", filters[:year])
    elsif filters[:year_range]
      start_year, end_year = filters[:year_range]
      scope.where("EXTRACT(year FROM shows.date) BETWEEN ? AND ?", start_year, end_year)
    elsif filters[:start_date] && filters[:end_date]
      scope.where(shows: { date: filters[:start_date]..filters[:end_date] })
    else
      scope
    end
  end

  def apply_tour_filter(scope)
    return scope unless filters[:tour_slug]
    scope.joins(show: :tour).where(tours: { slug: filters[:tour_slug] })
  end

  def apply_song_filter(scope)
    return scope unless filters[:song_slug]
    scope.where(songs: { slug: filters[:song_slug] })
  end

  def apply_venue_filter(scope)
    return scope unless filters[:venue_slug]
    scope.joins(show: :venue).where(venues: { slug: filters[:venue_slug] })
  end

  def apply_state_filter(scope)
    return scope unless filters[:state]
    scope.joins(show: :venue).where(venues: { state: filters[:state] })
  end

  # Analysis Type 1: Gaps (Bustout Hunting)
  def analyze_gaps
    min_gap = filters[:min_gap] || 20

    song_gaps = Song.joins(tracks: :show)
                    .where.not(tracks: { set: EXCLUDED_SETS })
                    .where(tracks: { exclude_from_stats: false })
                    .where("shows.performance_gap_value > 0")
                    .group("songs.id", "songs.title", "songs.slug")
                    .select(
                      "songs.id",
                      "songs.title",
                      "songs.slug",
                      "MAX(shows.date) as last_played",
                      "COUNT(DISTINCT tracks.id) as times_played"
                    )

    latest_show = Show.where("performance_gap_value > 0").order(date: :desc).first
    return { songs: [], latest_show_date: nil } unless latest_show

    results = song_gaps.map do |song_data|
      shows_since = Show.where("date > ? AND performance_gap_value > 0", song_data.last_played)
                        .sum(:performance_gap_value)
      next if shows_since < min_gap

      last_played_date = song_data.last_played.iso8601
      {
        song: song_data.title,
        slug: song_data.slug,
        url: McpHelpers.song_url(song_data.slug),
        last_played: last_played_date,
        last_played_show_url: McpHelpers.show_url(last_played_date),
        gap: shows_since,
        times_played: song_data.times_played
      }
    end.compact.sort_by { |r| -r[:gap] }.first(limit)

    { songs: results, latest_show_date: latest_show.date.iso8601 }
  end

  # Analysis Type 2: Transitions (Song Pairings)
  def analyze_transitions
    song_slug = filters[:song_slug]
    direction = filters[:direction] || "after"

    if song_slug
      analyze_song_transitions(song_slug, direction)
    else
      analyze_common_transitions
    end
  end

  def analyze_song_transitions(song_slug, direction)
    song = Song.find_by(slug: song_slug)
    return { error: "Song not found" } unless song

    tracks_with_song = Track.joins(:songs, :show)
                            .where(songs: { id: song.id })
                            .where.not(set: EXCLUDED_SETS)
                            .where(exclude_from_stats: false)
                            .includes(:show)

    transitions = {}

    tracks_with_song.find_each do |track|
      adjacent_track = if direction == "after"
        Track.where(show_id: track.show_id)
             .where("position > ?", track.position)
             .where.not(set: EXCLUDED_SETS)
             .order(:position)
             .first
      else
        Track.where(show_id: track.show_id)
             .where("position < ?", track.position)
             .where.not(set: EXCLUDED_SETS)
             .order(position: :desc)
             .first
      end

      next unless adjacent_track

      adjacent_track.songs.each do |adjacent_song|
        transitions[adjacent_song.slug] ||= { song: adjacent_song.title, slug: adjacent_song.slug, url: adjacent_song.url, count: 0 }
        transitions[adjacent_song.slug][:count] += 1
      end
    end

    total = transitions.values.sum { |t| t[:count] }
    results = transitions.values
                         .map { |t| t.merge(percentage: total > 0 ? (t[:count].to_f / total * 100).round(1) : 0) }
                         .sort_by { |t| -t[:count] }
                         .first(limit)

    {
      song: song.title,
      url: song.url,
      direction:,
      total_transitions: total,
      transitions: results
    }
  end

  def analyze_common_transitions
    transition_counts = Hash.new(0)

    Show.includes(tracks: :songs)
        .where("performance_gap_value > 0")
        .find_each do |show|
      tracks = show.tracks.where.not(set: EXCLUDED_SETS)
                   .where(exclude_from_stats: false)
                   .order(:position)

      tracks.each_cons(2) do |track1, track2|
        track1.songs.each do |song1|
          track2.songs.each do |song2|
            key = "#{song1.slug}->#{song2.slug}"
            transition_counts[key] += 1
          end
        end
      end
    end

    results = transition_counts.map do |key, count|
      from_slug, to_slug = key.split("->")
      from_song = Song.find_by(slug: from_slug)
      to_song = Song.find_by(slug: to_slug)
      next unless from_song && to_song

      {
        from: from_song.title,
        from_slug:,
        to: to_song.title,
        to_slug:,
        count:
      }
    end.compact.sort_by { |r| -r[:count] }.first(limit)

    { transitions: results }
  end

  # Analysis Type 3: Set Positions
  def analyze_set_positions
    position_type = filters[:position]

    case position_type
    when "opener"
      analyze_openers
    when "closer"
      analyze_closers
    when "encore"
      analyze_encores
    else
      analyze_song_position_distribution
    end
  end

  def analyze_openers
    set_filter = filters[:set] || "1"
    opener_track_ids = find_position_tracks(:first, set_filter)
    count_songs_in_tracks(opener_track_ids, "opener", set_filter)
  end

  def analyze_closers
    set_filter = filters[:set] || "2"
    closer_track_ids = find_position_tracks(:last, set_filter)
    count_songs_in_tracks(closer_track_ids, "closer", set_filter)
  end

  def analyze_encores
    encore_track_ids = Track.joins(:show)
                            .where(set: %w[E E2])
                            .where.not(exclude_from_stats: true)
                            .where("shows.performance_gap_value > 0")
    encore_track_ids = apply_date_filters(encore_track_ids)
    encore_track_ids = apply_tour_filter(encore_track_ids)
    encore_track_ids = encore_track_ids.pluck(:id)

    count_songs_in_tracks(encore_track_ids, "encore", "E")
  end

  def find_position_tracks(position, set_filter)
    scope = Track.joins(:show)
                 .where(set: set_filter)
                 .where(exclude_from_stats: false)
                 .where("shows.performance_gap_value > 0")

    scope = apply_date_filters(scope)
    scope = apply_tour_filter(scope)

    order_direction = position == :first ? "ASC" : "DESC"
    scope.select("DISTINCT ON (shows.id) tracks.id")
         .order(Arel.sql("shows.id, tracks.position #{order_direction}"))
         .pluck(:id)
  end

  def count_songs_in_tracks(track_ids, position_name, set_name)
    song_counts = Track.joins(:songs)
                       .where(id: track_ids)
                       .group("songs.title", "songs.slug")
                       .order("count_all DESC")
                       .limit(limit)
                       .count

    total = song_counts.values.sum
    results = song_counts.map do |k, v|
      {
        song: k[0],
        slug: k[1],
        url: McpHelpers.song_url(k[1]),
        count: v,
        percentage: total > 0 ? (v.to_f / total * 100).round(1) : 0
      }
    end

    {
      position: position_name,
      set: SET_NAMES[set_name] || set_name,
      total_shows: track_ids.count,
      songs: results
    }
  end

  def analyze_song_position_distribution
    song_slug = filters[:song_slug]
    return { error: "song_slug required" } unless song_slug

    song = Song.find_by(slug: song_slug)
    return { error: "Song not found" } unless song

    tracks = base_tracks.where(songs: { id: song.id }).includes(:show)

    by_set = tracks.group(:set).count

    opener_count = 0
    closer_count = 0

    tracks.find_each do |track|
      set_tracks = Track.where(show_id: track.show_id, set: track.set)
                        .where.not(set: EXCLUDED_SETS)
                        .where(exclude_from_stats: false)

      opener_count += 1 if track.position == set_tracks.minimum(:position)
      closer_count += 1 if track.position == set_tracks.maximum(:position)
    end

    total = tracks.count
    {
      song: song.title,
      total_performances: total,
      by_set: SET_NAMES.keys.map { |s| { set: SET_NAMES[s], count: by_set[s] || 0 } },
      opener_count:,
      closer_count:,
      opener_pct: total > 0 ? (opener_count.to_f / total * 100).round(1) : 0,
      closer_pct: total > 0 ? (closer_count.to_f / total * 100).round(1) : 0
    }
  end

  # Analysis Type 4: Predictions
  def analyze_predictions
    top_n = filters[:limit] || 15

    candidates = Song.joins(tracks: :show)
                     .where.not(tracks: { set: EXCLUDED_SETS })
                     .where(tracks: { exclude_from_stats: false })
                     .where("shows.performance_gap_value > 0")
                     .group("songs.id", "songs.title", "songs.slug")
                     .having("COUNT(tracks.id) >= ?", 10)
                     .select(
                       "songs.id",
                       "songs.title",
                       "songs.slug",
                       "MAX(shows.date) as last_played",
                       "COUNT(DISTINCT tracks.id) as times_played"
                     )

    latest_show = Show.where("performance_gap_value > 0").order(date: :desc).first
    return { predictions: [], latest_show_date: nil } unless latest_show

    scored = candidates.map do |song_data|
      gap = Show.where("date > ? AND performance_gap_value > 0", song_data.last_played)
                .sum(:performance_gap_value)

      avg_gap = calculate_average_gap(song_data.id, song_data.times_played)
      gap_ratio = avg_gap > 0 ? (gap.to_f / avg_gap) : 0
      last_played_date = song_data.last_played.iso8601

      {
        song: song_data.title,
        slug: song_data.slug,
        url: McpHelpers.song_url(song_data.slug),
        last_played: last_played_date,
        last_played_show_url: McpHelpers.show_url(last_played_date),
        current_gap: gap,
        times_played: song_data.times_played,
        avg_gap: avg_gap.round(1),
        gap_ratio: gap_ratio.round(2),
        score: (gap_ratio * Math.log(song_data.times_played + 1)).round(2)
      }
    end.sort_by { |r| -r[:score] }.first(top_n)

    { predictions: scored, latest_show_date: latest_show.date.iso8601 }
  end

  def calculate_average_gap(song_id, times_played)
    return 0 if times_played <= 1

    first_played = Track.joins(:songs, :show)
                        .where(songs: { id: song_id })
                        .where.not(set: EXCLUDED_SETS)
                        .where("shows.performance_gap_value > 0")
                        .minimum("shows.date")

    last_played = Track.joins(:songs, :show)
                       .where(songs: { id: song_id })
                       .where.not(set: EXCLUDED_SETS)
                       .where("shows.performance_gap_value > 0")
                       .maximum("shows.date")

    return 0 unless first_played && last_played

    shows_in_range = Show.where(date: first_played..last_played)
                         .where("performance_gap_value > 0")
                         .sum(:performance_gap_value)

    shows_in_range.to_f / times_played
  end

  # Analysis Type 5: Streaks
  def analyze_streaks
    song_slug = filters[:song_slug]
    streak_type = filters[:streak_type] || "current"

    if song_slug
      analyze_song_streak(song_slug, streak_type)
    else
      analyze_active_streaks
    end
  end

  def analyze_song_streak(song_slug, _streak_type)
    song = Song.find_by(slug: song_slug)
    return { error: "Song not found" } unless song

    shows_with_song_ids = Set.new(
      Show.joins(tracks: :songs)
          .where(songs: { id: song.id })
          .where.not(tracks: { set: EXCLUDED_SETS })
          .where("shows.performance_gap_value > 0")
          .distinct
          .pluck(:id)
    )

    all_shows = Show.where("performance_gap_value > 0")
                    .order(:date)
                    .pluck(:id, :date)

    streaks = find_streaks(all_shows, shows_with_song_ids)

    current_streak = calculate_current_streak_for_song(song.id)
    longest_streak = streaks.max_by { |s| s[:length] } || { length: 0 }

    {
      song: song.title,
      current_streak:,
      longest_streak: longest_streak[:length],
      longest_streak_dates: longest_streak[:length] > 0 ? "#{longest_streak[:start_date]} to #{longest_streak[:end_date]}" : nil,
      all_streaks: streaks.sort_by { |s| -s[:length] }.first(10)
    }
  end

  def calculate_current_streak_for_song(song_id)
    all_shows = Show.where("performance_gap_value > 0").order(date: :desc).pluck(:id)
    shows_with_song = Set.new(
      Track.joins(:songs)
           .where(songs: { id: song_id })
           .where.not(set: EXCLUDED_SETS)
           .where(exclude_from_stats: false)
           .pluck(:show_id)
    )

    streak = 0
    all_shows.each do |show_id|
      if shows_with_song.include?(show_id)
        streak += 1
      else
        break
      end
    end
    streak
  end

  def find_streaks(all_shows, shows_with_song_ids)
    streaks = []
    current_streak_start = nil
    current_streak_length = 0
    previous_date = nil

    all_shows.each do |show_id, date|
      if shows_with_song_ids.include?(show_id)
        current_streak_start ||= date
        current_streak_length += 1
      elsif current_streak_length > 0
        streaks << {
          start_date: current_streak_start.iso8601,
          end_date: previous_date.iso8601,
          length: current_streak_length
        }
        current_streak_start = nil
        current_streak_length = 0
      end
      previous_date = date
    end

    if current_streak_length > 0
      streaks << {
        start_date: current_streak_start.iso8601,
        end_date: all_shows.last[1].iso8601,
        length: current_streak_length
      }
    end

    streaks.select { |s| s[:length] >= 3 }
  end

  def analyze_active_streaks
    latest_show = Show.where("performance_gap_value > 0").order(date: :desc).first
    return { streaks: [] } unless latest_show

    recent_shows = Show.where("performance_gap_value > 0")
                       .order(date: :desc)
                       .limit(50)
                       .pluck(:id)

    songs_in_recent = Track.joins(:songs)
                           .where(show_id: recent_shows)
                           .where.not(set: EXCLUDED_SETS)
                           .where(exclude_from_stats: false)
                           .group("songs.id", "songs.title", "songs.slug")
                           .count

    streaks = songs_in_recent.map do |key, _|
      song_id, title, slug = key
      streak = calculate_current_streak(song_id)
      next if streak < 3

      { song: title, slug:, url: McpHelpers.song_url(slug), current_streak: streak }
    end.compact.sort_by { |s| -s[:current_streak] }.first(limit)

    { streaks:, as_of: latest_show.date.iso8601 }
  end

  def calculate_current_streak(song_id)
    all_shows = Show.where("performance_gap_value > 0").order(date: :desc).pluck(:id)
    shows_with_song = Set.new(
      Track.joins(:songs)
           .where(songs: { id: song_id })
           .where.not(set: EXCLUDED_SETS)
           .pluck(:show_id)
    )

    streak = 0
    all_shows.each do |show_id|
      if shows_with_song.include?(show_id)
        streak += 1
      else
        break
      end
    end
    streak
  end

  # Analysis Type 6: Geographic
  def analyze_geographic
    geo_type = filters[:geo_type] || "state_frequency"

    case geo_type
    when "state_frequency"
      analyze_state_frequency
    when "never_played"
      analyze_never_played_in_state
    when "state_debuts"
      analyze_state_debuts
    else
      { error: "Unknown geo_type" }
    end
  end

  def analyze_state_frequency
    state_counts = Show.joins(:venue)
                       .where("shows.performance_gap_value > 0")
                       .where(venues: { country: "USA" })
                       .group("venues.state")
                       .order("count_all DESC")
                       .count

    results = state_counts.map { |state, count| { state:, show_count: count } }

    { states: results }
  end

  def analyze_never_played_in_state
    state = filters[:state]
    return { error: "state required" } unless state

    shows_in_state = Show.joins(:venue)
                         .where(venues: { state: })
                         .where("shows.performance_gap_value > 0")
                         .pluck(:id)

    songs_played_in_state = Track.joins(:songs)
                                 .where(show_id: shows_in_state)
                                 .where.not(set: EXCLUDED_SETS)
                                 .pluck("songs.id")
                                 .uniq

    all_played_songs = Track.joins(:songs)
                            .where.not(set: EXCLUDED_SETS)
                            .where(exclude_from_stats: false)
                            .select("DISTINCT songs.id")
                            .pluck("songs.id")

    never_played_ids = all_played_songs - songs_played_in_state

    songs = Song.where(id: never_played_ids)
                .joins(:tracks)
                .group("songs.id", "songs.title", "songs.slug")
                .having("COUNT(tracks.id) >= ?", 10)
                .order("COUNT(tracks.id) DESC")
                .limit(limit)
                .select("songs.id", "songs.title", "songs.slug", "COUNT(tracks.id) as times_played")

    results = songs.map do |song|
      { song: song.title, slug: song.slug, times_played_elsewhere: song.times_played }
    end

    { state:, never_played_songs: results }
  end

  def analyze_state_debuts
    state = filters[:state]
    return { error: "state required" } unless state

    shows_in_state = Show.joins(:venue)
                         .where(venues: { state: })
                         .where("shows.performance_gap_value > 0")
                         .order(:date)

    debuts = []
    songs_seen = Set.new

    shows_in_state.includes(tracks: :songs).find_each do |show|
      show.tracks.each do |track|
        next if EXCLUDED_SETS.include?(track.set)

        track.songs.each do |song|
          unless songs_seen.include?(song.id)
            songs_seen.add(song.id)
            debuts << {
              song: song.title,
              slug: song.slug,
              url: song.url,
              date: show.date.iso8601,
              show_url: show.url,
              venue: show.venue_name
            }
          end
        end
      end
    end

    { state:, debuts: debuts.last(limit).reverse }
  end

  # Analysis Type 7: Co-occurrence (Song Pairings in Same Show)
  def analyze_co_occurrence
    song_a_slug = filters[:song_slug]
    song_b_slug = filters[:song_b_slug]

    return { error: "song_slug required" } unless song_a_slug

    if song_b_slug
      analyze_song_pair(song_a_slug, song_b_slug)
    else
      analyze_common_pairings(song_a_slug)
    end
  end

  def analyze_song_pair(song_a_slug, song_b_slug)
    song_a = Song.find_by(slug: song_a_slug)
    song_b = Song.find_by(slug: song_b_slug)
    return { error: "Song A not found" } unless song_a
    return { error: "Song B not found" } unless song_b

    shows_a = shows_with_song(song_a.id)
    shows_b = shows_with_song(song_b.id)

    both = shows_a & shows_b
    only_a = shows_a - shows_b
    only_b = shows_b - shows_a

    {
      song_a: song_a.title,
      song_b: song_b.title,
      shows_with_both: both.count,
      shows_with_only_a: only_a.count,
      shows_with_only_b: only_b.count,
      co_occurrence_pct: shows_a.any? ? (both.count.to_f / shows_a.count * 100).round(1) : 0,
      only_a_dates: fetch_show_dates(only_a),
      only_b_dates: fetch_show_dates(only_b)
    }
  end

  def analyze_common_pairings(song_slug)
    song = Song.find_by(slug: song_slug)
    return { error: "Song not found" } unless song

    show_ids = shows_with_song(song.id)

    pairings = Track.joins(:songs)
                    .where(show_id: show_ids)
                    .where.not(songs: { id: song.id })
                    .where.not(set: EXCLUDED_SETS)
                    .group("songs.title", "songs.slug")
                    .order("count_all DESC")
                    .limit(limit)
                    .count

    results = pairings.map do |k, v|
      { song: k[0], slug: k[1], url: McpHelpers.song_url(k[1]), count: v, pct: (v.to_f / show_ids.count * 100).round(1) }
    end

    { song: song.title, url: song.url, total_shows: show_ids.count, common_pairings: results }
  end

  def shows_with_song(song_id)
    Show.joins(tracks: :songs)
        .where(songs: { id: song_id })
        .where.not(tracks: { set: EXCLUDED_SETS })
        .where("shows.performance_gap_value > 0")
        .distinct
        .pluck(:id)
  end

  def fetch_show_dates(show_ids)
    Show.where(id: show_ids)
        .order(date: :desc)
        .limit(limit)
        .pluck(:date)
        .map(&:iso8601)
  end

  # Analysis Type 8: Song Frequency
  def analyze_song_frequency
    song_counts = base_tracks.group("songs.id", "songs.title", "songs.slug")
                             .select(
                               "songs.id",
                               "songs.title",
                               "songs.slug",
                               "COUNT(DISTINCT tracks.id) as times_played"
                             )
                             .order("times_played DESC")
                             .limit(limit)

    results = song_counts.map do |song_data|
      {
        song: song_data.title,
        slug: song_data.slug,
        url: McpHelpers.song_url(song_data.slug),
        times_played: song_data.times_played
      }
    end

    filter_description = build_filter_description
    { songs: results, filter: filter_description }
  end

  def build_filter_description
    parts = []
    parts << "year: #{filters[:year]}" if filters[:year]
    parts << "years: #{filters[:year_range].join('-')}" if filters[:year_range]
    parts << "tour: #{filters[:tour_slug]}" if filters[:tour_slug]
    parts << "venue: #{filters[:venue_slug]}" if filters[:venue_slug]
    parts << "state: #{filters[:state]}" if filters[:state]
    parts.empty? ? "all time" : parts.join(", ")
  end

  def format_duration(ms)
    return "0:00" unless ms&.positive?

    total_seconds = ms / 1000
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end

  def log_mcp_call(result, start_time)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    McpToolCall.log_call(
      tool_name: "stats",
      parameters: { analysis_type: analysis_type.to_s }.merge(filters),
      result:,
      duration_ms:
    )
  end
end
