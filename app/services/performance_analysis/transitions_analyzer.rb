module PerformanceAnalysis
  class TransitionsAnalyzer < BaseAnalyzer
    def call
      song_slug = filters[:song_slug]
      direction = filters[:direction] || "after"

      if song_slug
        analyze_song_transitions(song_slug, direction)
      else
        analyze_common_transitions
      end
    end

    private

    def analyze_song_transitions(song_slug, direction)
      song = Song.find_by(slug: song_slug)
      return { error: "Song not found" } unless song

      transition_data = fetch_song_transition_counts(song.id, direction)

      song_slugs = transition_data.map { |row| row["adjacent_slug"] }.uniq
      songs_by_slug = Song.where(slug: song_slugs).index_by(&:slug)

      total = transition_data.sum { |row| row["count"].to_i }

      top_transitions = transition_data.first(limit)
      adjacent_slugs = top_transitions.map { |row| row["adjacent_slug"] }
      examples_by_slug = fetch_song_transition_examples(song.id, direction, adjacent_slugs)

      results = top_transitions.filter_map do |row|
        adjacent_song = songs_by_slug[row["adjacent_slug"]]
        next unless adjacent_song

        count = row["count"].to_i
        {
          song: adjacent_song.title,
          slug: adjacent_song.slug,
          url: adjacent_song.url,
          count:,
          percentage: total > 0 ? (count.to_f / total * 100).round(1) : 0,
          examples: examples_by_slug[row["adjacent_slug"]] || []
        }
      end

      {
        song: song.title,
        url: song.url,
        direction:,
        total_transitions: total,
        transitions: results
      }
    end

    def fetch_song_transition_counts(song_id, direction)
      position_comparison = direction == "after" ? ">" : "<"
      position_order = direction == "after" ? "ASC" : "DESC"

      sql = <<~SQL
        WITH source_tracks AS (
          SELECT t.id, t.show_id, t.position
          FROM tracks t
          INNER JOIN songs_tracks st ON st.track_id = t.id
          INNER JOIN shows s ON s.id = t.show_id
          WHERE st.song_id = #{song_id}
            AND t.set NOT IN ('S', 'P')
            AND t.exclude_from_stats = FALSE
            AND s.performance_gap_value > 0
        ),
        adjacent_tracks AS (
          SELECT DISTINCT ON (src.id)
            src.id AS source_track_id,
            adj.id AS adjacent_track_id
          FROM source_tracks src
          INNER JOIN tracks adj ON adj.show_id = src.show_id
            AND adj.position #{position_comparison} src.position
            AND adj.set NOT IN ('S', 'P')
          ORDER BY src.id, adj.position #{position_order}
        )
        SELECT
          s.slug AS adjacent_slug,
          COUNT(*) AS count
        FROM adjacent_tracks at
        INNER JOIN songs_tracks st ON st.track_id = at.adjacent_track_id
        INNER JOIN songs s ON s.id = st.song_id
        GROUP BY s.slug
        ORDER BY count DESC
      SQL

      ActiveRecord::Base.connection.execute(sql).to_a
    end

    def fetch_song_transition_examples(song_id, direction, adjacent_slugs, examples_per_song: 3)
      return {} if adjacent_slugs.empty?

      position_comparison = direction == "after" ? ">" : "<"
      position_order = direction == "after" ? "ASC" : "DESC"
      quoted_slugs = adjacent_slugs.map { |s| ActiveRecord::Base.connection.quote(s) }.join(", ")

      sql = <<~SQL
        WITH source_tracks AS (
          SELECT t.id, t.show_id, t.position
          FROM tracks t
          INNER JOIN songs_tracks st ON st.track_id = t.id
          INNER JOIN shows s ON s.id = t.show_id
          WHERE st.song_id = #{song_id}
            AND t.set NOT IN ('S', 'P')
            AND t.exclude_from_stats = FALSE
            AND s.performance_gap_value > 0
        ),
        adjacent_tracks AS (
          SELECT DISTINCT ON (src.id)
            src.id AS source_track_id,
            adj.id AS adjacent_track_id,
            src.show_id
          FROM source_tracks src
          INNER JOIN tracks adj ON adj.show_id = src.show_id
            AND adj.position #{position_comparison} src.position
            AND adj.set NOT IN ('S', 'P')
          ORDER BY src.id, adj.position #{position_order}
        ),
        transition_shows AS (
          SELECT
            s.slug AS adjacent_slug,
            sh.date,
            ROW_NUMBER() OVER (PARTITION BY s.slug ORDER BY sh.date DESC) AS rn
          FROM adjacent_tracks at
          INNER JOIN songs_tracks st ON st.track_id = at.adjacent_track_id
          INNER JOIN songs s ON s.id = st.song_id
          INNER JOIN shows sh ON sh.id = at.show_id
          WHERE s.slug IN (#{quoted_slugs})
        )
        SELECT adjacent_slug, date
        FROM transition_shows
        WHERE rn <= #{examples_per_song}
        ORDER BY adjacent_slug, date DESC
      SQL

      results = ActiveRecord::Base.connection.execute(sql).to_a
      results.each_with_object({}) do |row, hash|
        slug = row["adjacent_slug"]
        hash[slug] ||= []
        hash[slug] << {
          date: row["date"].to_s,
          url: "#{App.base_url}/#{row['date']}"
        }
      end
    end

    def analyze_common_transitions
      transition_data = fetch_transition_counts

      song_slugs = transition_data.flat_map { |row| [ row["from_slug"], row["to_slug"] ] }.uniq
      songs_by_slug = Song.where(slug: song_slugs).index_by(&:slug)

      top_transitions = transition_data.first(limit)
      transition_pairs = top_transitions.map { |row| [ row["from_slug"], row["to_slug"] ] }
      examples_by_pair = fetch_transition_examples(transition_pairs)

      results = top_transitions.filter_map do |row|
        from_song = songs_by_slug[row["from_slug"]]
        to_song = songs_by_slug[row["to_slug"]]
        next unless from_song && to_song

        pair_key = "#{row['from_slug']}|#{row['to_slug']}"
        {
          from: from_song.title,
          from_slug: row["from_slug"],
          to: to_song.title,
          to_slug: row["to_slug"],
          count: row["count"].to_i,
          examples: examples_by_pair[pair_key] || []
        }
      end

      { transitions: results }
    end

    def fetch_transition_counts
      sql = <<~SQL
        WITH ordered_tracks AS (
          SELECT
            t.id,
            t.show_id,
            t.position,
            ROW_NUMBER() OVER (PARTITION BY t.show_id ORDER BY t.position) AS track_num
          FROM tracks t
          INNER JOIN shows s ON s.id = t.show_id
          WHERE t.set NOT IN ('S', 'P')
            AND t.exclude_from_stats = FALSE
            AND s.performance_gap_value > 0
        ),
        track_pairs AS (
          SELECT
            ot1.id AS track1_id,
            ot2.id AS track2_id
          FROM ordered_tracks ot1
          INNER JOIN ordered_tracks ot2
            ON ot1.show_id = ot2.show_id
            AND ot2.track_num = ot1.track_num + 1
        ),
        transitions AS (
          SELECT
            s1.slug AS from_slug,
            s2.slug AS to_slug,
            COUNT(*) AS count
          FROM track_pairs tp
          INNER JOIN songs_tracks st1 ON st1.track_id = tp.track1_id
          INNER JOIN songs s1 ON s1.id = st1.song_id
          INNER JOIN songs_tracks st2 ON st2.track_id = tp.track2_id
          INNER JOIN songs s2 ON s2.id = st2.song_id
          GROUP BY s1.slug, s2.slug
        )
        SELECT from_slug, to_slug, count
        FROM transitions
        ORDER BY count DESC
        LIMIT #{limit * 2}
      SQL

      ActiveRecord::Base.connection.execute(sql).to_a
    end

    def fetch_transition_examples(transition_pairs, examples_per_pair: 3)
      return {} if transition_pairs.empty?

      pair_conditions = transition_pairs.map do |from_slug, to_slug|
        "(s1.slug = #{ActiveRecord::Base.connection.quote(from_slug)} AND s2.slug = #{ActiveRecord::Base.connection.quote(to_slug)})"
      end.join(" OR ")

      sql = <<~SQL
        WITH ordered_tracks AS (
          SELECT
            t.id,
            t.show_id,
            t.position,
            ROW_NUMBER() OVER (PARTITION BY t.show_id ORDER BY t.position) AS track_num
          FROM tracks t
          INNER JOIN shows s ON s.id = t.show_id
          WHERE t.set NOT IN ('S', 'P')
            AND t.exclude_from_stats = FALSE
            AND s.performance_gap_value > 0
        ),
        track_pairs AS (
          SELECT
            ot1.id AS track1_id,
            ot2.id AS track2_id,
            ot1.show_id
          FROM ordered_tracks ot1
          INNER JOIN ordered_tracks ot2
            ON ot1.show_id = ot2.show_id
            AND ot2.track_num = ot1.track_num + 1
        ),
        transition_shows AS (
          SELECT
            s1.slug AS from_slug,
            s2.slug AS to_slug,
            sh.date,
            ROW_NUMBER() OVER (PARTITION BY s1.slug, s2.slug ORDER BY sh.date DESC) AS rn
          FROM track_pairs tp
          INNER JOIN songs_tracks st1 ON st1.track_id = tp.track1_id
          INNER JOIN songs s1 ON s1.id = st1.song_id
          INNER JOIN songs_tracks st2 ON st2.track_id = tp.track2_id
          INNER JOIN songs s2 ON s2.id = st2.song_id
          INNER JOIN shows sh ON sh.id = tp.show_id
          WHERE #{pair_conditions}
        )
        SELECT from_slug, to_slug, date
        FROM transition_shows
        WHERE rn <= #{examples_per_pair}
        ORDER BY from_slug, to_slug, date DESC
      SQL

      results = ActiveRecord::Base.connection.execute(sql).to_a
      results.each_with_object({}) do |row, hash|
        pair_key = "#{row['from_slug']}|#{row['to_slug']}"
        hash[pair_key] ||= []
        hash[pair_key] << {
          date: row["date"].to_s,
          url: "#{App.base_url}/#{row['date']}"
        }
      end
    end
  end
end
