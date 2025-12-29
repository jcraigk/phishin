module PerformanceAnalysis
  class SongFrequencyAnalyzer < BaseAnalyzer
    def call
      song_counts = base_tracks.where.not(songs: { slug: EXCLUDED_SONGS })
                               .group("songs.id", "songs.title", "songs.slug")
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

    private

    def build_filter_description
      parts = []
      parts << "year: #{filters[:year]}" if filters[:year]
      parts << "years: #{filters[:year_range].join('-')}" if filters[:year_range]
      parts << "tour: #{filters[:tour_slug]}" if filters[:tour_slug]
      parts << "venue: #{filters[:venue_slug]}" if filters[:venue_slug]
      parts << "state: #{filters[:state]}" if filters[:state]
      parts.empty? ? "all time" : parts.join(", ")
    end
  end
end
