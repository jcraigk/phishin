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
  end
end
