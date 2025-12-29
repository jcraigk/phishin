module PerformanceAnalysis
  class GapsAnalyzer < BaseAnalyzer
    def call
      min_gap = filters[:min_gap] || 20
      min_plays = filters[:min_plays] || 2

      song_gaps = Song.joins(tracks: :show)
                      .where.not(tracks: { set: EXCLUDED_SETS })
                      .where.not(songs: { slug: EXCLUDED_SONGS })
                      .where(tracks: { exclude_from_stats: false })
                      .where("shows.performance_gap_value > 0")
                      .where("songs.tracks_count >= ?", min_plays)
                      .group("songs.id", "songs.title", "songs.slug", "songs.tracks_count")
                      .select(
                        "songs.id",
                        "songs.title",
                        "songs.slug",
                        "songs.tracks_count",
                        "MAX(shows.date) as last_played"
                      )

      latest_show = Show.where("performance_gap_value > 0").order(date: :desc).first
      return { songs: [], latest_show_date: nil } unless latest_show

      results = song_gaps.map do |song_data|
        shows_since = Show.where("date > ? AND performance_gap_value > 0", song_data.last_played)
                          .sum(:performance_gap_value)
        next if shows_since < min_gap

        last_played_date = song_data.last_played.iso8601
        last_track = Track.joins(:show, :songs)
                          .where(shows: { date: song_data.last_played })
                          .find_by(songs: { id: song_data.id })
        {
          song: song_data.title,
          slug: song_data.slug,
          url: McpHelpers.song_url(song_data.slug),
          last_played: last_played_date,
          last_played_track_url: last_track ? McpHelpers.track_url(last_played_date, last_track.slug) : nil,
          gap: shows_since,
          times_played: song_data.tracks_count
        }
      end.compact.sort_by { |r| -r[:gap] }.first(limit)

      { songs: results, latest_show_date: latest_show.date.iso8601 }
    end
  end
end
