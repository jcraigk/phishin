module Tools
  class ListShows < MCP::Tool
    tool_name "list_shows"

    description Descriptions::BASE[:list_shows]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        year: { type: "integer", description: "Filter by year (e.g., 1997)" },
        start_date: { type: "string", description: "Start date for range filter (YYYY-MM-DD)" },
        end_date: { type: "string", description: "End date for range filter (YYYY-MM-DD)" },
        tour_slug: { type: "string", description: "Filter by tour slug (e.g., 'fall-tour-1997')" },
        venue_slug: { type: "string", description: "Filter by venue slug (e.g., 'madison-square-garden')" },
        sort_by: {
          type: "string",
          enum: %w[date likes duration random],
          description: "Sort by date (default), likes, duration, or random"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc (default for date) or desc"
        },
        limit: { type: "integer", description: "Max shows to return (default: 50)" }
      },
      required: []
    )

    class << self
      def call(
        year: nil,
        start_date: nil,
        end_date: nil,
        tour_slug: nil,
        venue_slug: nil,
        sort_by: "date",
        sort_order: nil,
        limit: 50
      )
        has_filter = year || start_date || end_date || tour_slug || venue_slug
        return error_response("At least one filter required: year, start_date, end_date, tour_slug, or venue_slug") unless has_filter

        sort_order ||= sort_by == "date" ? "asc" : "desc"

        result = fetch_shows(year, start_date, end_date, tour_slug, venue_slug, sort_by, sort_order, limit)
        return error_response("No shows found") unless result

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_shows(year, start_date, end_date, tour_slug, venue_slug, sort_by, sort_order, limit)
        if sort_by == "random"
          build_shows_result(year, start_date, end_date, tour_slug, venue_slug, sort_by, sort_order, limit)
        else
          cache_key = McpHelpers.cache_key_for_collection("shows", {
            year:, start_date:, end_date:, tour_slug:, venue_slug:, sort_by:, sort_order:, limit:
          })

          Rails.cache.fetch(cache_key) do
            build_shows_result(year, start_date, end_date, tour_slug, venue_slug, sort_by, sort_order, limit)
          end
        end
      end

      def build_shows_result(year, start_date, end_date, tour_slug, venue_slug, sort_by, sort_order, limit)
        shows = build_query(year, start_date, end_date, tour_slug, venue_slug)
        return nil if shows.empty?

        shows = apply_sort(shows, sort_by, sort_order)
        shows = shows.limit(limit) if limit

        show_list = shows.map { |show| build_show_data(show) }

        {
          total: show_list.size,
          filters: { year:, start_date:, end_date:, tour_slug:, venue_slug: }.compact,
          shows: show_list
        }
      end

      private

      def build_query(year, start_date, end_date, tour_slug, venue_slug)
        shows = Show.includes(:venue, :tour)

        shows = shows.where("EXTRACT(YEAR FROM date) = ?", year) if year
        shows = shows.where("date >= ?", start_date) if start_date
        shows = shows.where("date <= ?", end_date) if end_date
        shows = apply_tour_filter(shows, tour_slug) if tour_slug
        shows = apply_venue_filter(shows, venue_slug) if venue_slug

        shows
      end

      def build_show_data(show)
        {
          date: show.date.iso8601,
          url: show.url,
          venue: show.venue_name,
          venue_url: show.venue&.url,
          location: show.venue&.location,
          tour: show.tour&.name,
          duration_ms: show.duration,
          duration_display: McpHelpers.format_duration(show.duration),
          likes: show.likes_count,
          audio_status: show.audio_status
        }
      end

      def apply_tour_filter(shows, tour_slug)
        tour = Tour.find_by(slug: tour_slug)
        return shows.none unless tour
        shows.where(tour_id: tour.id)
      end

      def apply_venue_filter(shows, venue_slug)
        venue = Venue.find_by(slug: venue_slug)
        return shows.none unless venue
        shows.where(venue_id: venue.id)
      end

      def apply_sort(scope, sort_by, sort_order)
        direction = sort_order == "asc" ? :asc : :desc

        case sort_by
        when "likes"
          scope.order(likes_count: direction)
        when "duration"
          scope.order(duration: direction)
        when "random"
          scope.order(Arel.sql("RANDOM()"))
        else
          scope.order(date: direction)
        end
      end

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
