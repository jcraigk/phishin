module PerformanceAnalysis
  class SetPositionsAnalyzer < BaseAnalyzer
    def call
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

    private

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
      song_slugs = song_counts.keys.map { |k| k[1] }
      examples_by_slug = fetch_position_examples(track_ids, song_slugs)

      results = song_counts.map do |k, v|
        {
          song: k[0],
          slug: k[1],
          url: McpHelpers.song_url(k[1]),
          count: v,
          percentage: total > 0 ? (v.to_f / total * 100).round(1) : 0,
          examples: examples_by_slug[k[1]] || []
        }
      end

      {
        position: position_name,
        set: SET_NAMES[set_name] || set_name,
        total_shows: track_ids.count,
        songs: results
      }
    end

    def fetch_position_examples(track_ids, song_slugs, examples_per_song: 3)
      return {} if song_slugs.empty? || track_ids.empty?

      quoted_slugs = song_slugs.map { |s| ActiveRecord::Base.connection.quote(s) }.join(", ")

      sql = <<~SQL
        WITH unique_shows AS (
          SELECT DISTINCT
            s.slug AS song_slug,
            t.slug AS track_slug,
            sh.date
          FROM tracks t
          INNER JOIN songs_tracks st ON st.track_id = t.id
          INNER JOIN songs s ON s.id = st.song_id
          INNER JOIN shows sh ON sh.id = t.show_id
          WHERE t.id IN (#{track_ids.join(',')})
            AND s.slug IN (#{quoted_slugs})
        ),
        position_shows AS (
          SELECT
            song_slug,
            track_slug,
            date,
            ROW_NUMBER() OVER (PARTITION BY song_slug ORDER BY date DESC) AS rn
          FROM unique_shows
        )
        SELECT song_slug, track_slug, date
        FROM position_shows
        WHERE rn <= #{examples_per_song}
        ORDER BY song_slug, date DESC
      SQL

      results = ActiveRecord::Base.connection.execute(sql).to_a
      results.each_with_object({}) do |row, hash|
        slug = row["song_slug"]
        hash[slug] ||= []
        hash[slug] << {
          date: row["date"].to_s,
          url: McpHelpers.track_url(row["date"], row["track_slug"])
        }
      end
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
  end
end
