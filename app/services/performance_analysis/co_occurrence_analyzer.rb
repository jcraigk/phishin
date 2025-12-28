module PerformanceAnalysis
  class CoOccurrenceAnalyzer < BaseAnalyzer
    def call
      song_a_slug = filters[:song_slug]
      song_b_slug = filters[:song_b_slug]

      return { error: "song_slug required" } unless song_a_slug

      if song_b_slug
        analyze_song_pair(song_a_slug, song_b_slug)
      else
        analyze_common_pairings(song_a_slug)
      end
    end

    private

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
        example_shows: fetch_show_examples(both, song_a.id, song_b.id),
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

      paired_song_slugs = pairings.keys.map { |k| k[1] }
      examples_by_slug = fetch_pairing_examples(song.id, show_ids, paired_song_slugs)

      results = pairings.map do |k, v|
        {
          song: k[0],
          slug: k[1],
          url: McpHelpers.song_url(k[1]),
          count: v,
          pct: (v.to_f / show_ids.count * 100).round(1),
          examples: examples_by_slug[k[1]] || []
        }
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

    def fetch_show_examples(show_ids, song_a_id, song_b_id, examples_count: 3)
      return [] if show_ids.empty?

      sql = <<~SQL
        WITH show_dates AS (
          SELECT id, date
          FROM shows
          WHERE id IN (#{show_ids.join(',')})
          ORDER BY date DESC
          LIMIT #{examples_count}
        ),
        track_a AS (
          SELECT DISTINCT ON (t.show_id)
            t.show_id,
            t.slug AS track_slug
          FROM tracks t
          INNER JOIN songs_tracks st ON st.track_id = t.id
          WHERE st.song_id = #{song_a_id}
            AND t.show_id IN (SELECT id FROM show_dates)
          ORDER BY t.show_id, t.position
        ),
        track_b AS (
          SELECT DISTINCT ON (t.show_id)
            t.show_id,
            t.slug AS track_slug
          FROM tracks t
          INNER JOIN songs_tracks st ON st.track_id = t.id
          WHERE st.song_id = #{song_b_id}
            AND t.show_id IN (SELECT id FROM show_dates)
          ORDER BY t.show_id, t.position
        )
        SELECT
          sd.date,
          ta.track_slug AS track_a_slug,
          tb.track_slug AS track_b_slug
        FROM show_dates sd
        INNER JOIN track_a ta ON ta.show_id = sd.id
        INNER JOIN track_b tb ON tb.show_id = sd.id
        ORDER BY sd.date DESC
      SQL

      ActiveRecord::Base.connection.execute(sql).to_a.map do |row|
        date_str = row["date"].to_s
        {
          date: date_str,
          track_a_url: McpHelpers.track_url(date_str, row["track_a_slug"]),
          track_b_url: McpHelpers.track_url(date_str, row["track_b_slug"])
        }
      end
    end

    def fetch_pairing_examples(song_id, show_ids, paired_song_slugs, examples_per_song: 3)
      return {} if paired_song_slugs.empty? || show_ids.empty?

      quoted_slugs = paired_song_slugs.map { |s| ActiveRecord::Base.connection.quote(s) }.join(", ")

      sql = <<~SQL
        WITH paired_tracks AS (
          SELECT DISTINCT ON (s.slug, sh.id)
            s.slug AS song_slug,
            t.slug AS track_slug,
            sh.date
          FROM tracks t
          INNER JOIN songs_tracks st ON st.track_id = t.id
          INNER JOIN songs s ON s.id = st.song_id
          INNER JOIN shows sh ON sh.id = t.show_id
          WHERE t.show_id IN (#{show_ids.join(',')})
            AND s.slug IN (#{quoted_slugs})
            AND s.id != #{song_id}
          ORDER BY s.slug, sh.id, t.position
        ),
        ranked_tracks AS (
          SELECT
            song_slug,
            track_slug,
            date,
            ROW_NUMBER() OVER (PARTITION BY song_slug ORDER BY date DESC) AS rn
          FROM paired_tracks
        )
        SELECT song_slug, track_slug, date
        FROM ranked_tracks
        WHERE rn <= #{examples_per_song}
        ORDER BY song_slug, date DESC
      SQL

      results = ActiveRecord::Base.connection.execute(sql).to_a
      results.each_with_object({}) do |row, hash|
        slug = row["song_slug"]
        date_str = row["date"].to_s
        hash[slug] ||= []
        hash[slug] << { date: date_str, url: McpHelpers.track_url(date_str, row["track_slug"]) }
      end
    end
  end
end
