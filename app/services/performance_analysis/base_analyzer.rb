module PerformanceAnalysis
  class BaseAnalyzer
    EXCLUDED_SETS = %w[S P].freeze

    attr_reader :filters

    def initialize(filters: {})
      @filters = filters
    end

    def call
      raise NotImplementedError, "Subclasses must implement #call"
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

    def format_duration(ms)
      return "0:00" unless ms&.positive?

      total_seconds = ms / 1000
      minutes = total_seconds / 60
      seconds = total_seconds % 60
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end
end
