module PerformanceAnalysis
  class GeographicAnalyzer < BaseAnalyzer
    def call
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

    private

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
  end
end
