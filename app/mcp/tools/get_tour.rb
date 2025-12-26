module Mcp
  module Tools
    class GetTour < MCP::Tool
      description "Get detailed information about a Phish tour including show history. " \
                  "Returns tour metadata and a list of shows with dates, venues, likes, " \
                  "and duration for drilling down with get_show."

      input_schema(
        properties: {
          slug: { type: "string", description: "Tour slug (e.g., 'fall-1997', 'summer-2023')" },
          sort_by: {
            type: "string",
            enum: %w[date likes duration random],
            description: "Sort shows by date (default), likes, duration, or random"
          },
          sort_order: {
            type: "string",
            enum: %w[asc desc],
            description: "Sort order: asc or desc (default: asc for date, desc for others)"
          },
          limit: { type: "integer", description: "Max shows to return (default: all shows on tour)" }
        },
        required: [ "slug" ]
      )

      class << self
        def call(slug:, sort_by: "date", sort_order: nil, limit: nil)
          tour = Tour.find_by(slug:)
          return error_response("Tour not found") unless tour

          shows = Show.where(tour_id: tour.id).includes(:venue)

          sort_order ||= sort_by == "date" ? "asc" : "desc"
          shows = apply_sort(shows, sort_by, sort_order)
          shows = shows.limit(limit) if limit

          show_list = shows.map do |show|
            {
              date: show.date.iso8601,
              venue: show.venue_name,
              location: show.venue&.location,
              duration_ms: show.duration,
              duration_display: format_duration(show.duration),
              likes: show.likes_count
            }
          end

          result = {
            name: tour.name,
            slug: tour.slug,
            starts_on: tour.starts_on.iso8601,
            ends_on: tour.ends_on.iso8601,
            shows_count: tour.shows_count,
            shows: show_list
          }

          MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
        end

        private

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

        def format_duration(ms)
          return "0:00" unless ms&.positive?

          total_seconds = ms / 1000
          hours = total_seconds / 3600
          minutes = (total_seconds % 3600) / 60
          seconds = total_seconds % 60

          if hours > 0
            "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
          else
            "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
          end
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], is_error: true)
        end
      end
    end
  end
end
