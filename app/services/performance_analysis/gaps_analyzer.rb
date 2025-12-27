module PerformanceAnalysis
  class GapsAnalyzer < BaseAnalyzer
    def call
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
  end
end
