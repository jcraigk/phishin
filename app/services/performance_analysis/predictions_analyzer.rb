module PerformanceAnalysis
  class PredictionsAnalyzer < BaseAnalyzer
    def call
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

    private

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
  end
end
