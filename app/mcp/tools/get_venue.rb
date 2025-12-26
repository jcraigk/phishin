module Mcp
  module Tools
    class GetVenue < MCP::Tool
      description "Get detailed information about a venue including show history. " \
                  "Returns venue metadata and a list of shows with dates, likes, " \
                  "and duration for drilling down with get_show."

      input_schema(
        properties: {
          slug: { type: "string", description: "Venue slug (e.g., 'madison-square-garden')" },
          sort_by: {
            type: "string",
            enum: %w[date likes duration random],
            description: "Sort shows by date (default), likes, duration, or random"
          },
          sort_order: {
            type: "string",
            enum: %w[asc desc],
            description: "Sort order: asc or desc (default: desc)"
          },
          limit: { type: "integer", description: "Max shows to return (default: 25)" }
        },
        required: [ "slug" ]
      )

      class << self
        def call(slug:, sort_by: "date", sort_order: "desc", limit: 25)
          venue = Venue.find_by(slug:)
          return error_response("Venue not found") unless venue

          shows = Show.where(venue_id: venue.id)
                      .where("duration > 0")

          shows = apply_sort(shows, sort_by, sort_order)
          shows = shows.limit(limit)

          show_list = shows.map do |show|
            {
              date: show.date.iso8601,
              duration_ms: show.duration,
              duration_display: format_duration(show.duration),
              likes: show.likes_count,
              tour: show.tour&.name
            }
          end

          first_show = Show.where(venue_id: venue.id).order(date: :asc).first
          last_show = Show.where(venue_id: venue.id).order(date: :desc).first

          result = {
            name: venue.name,
            slug: venue.slug,
            city: venue.city,
            state: venue.state,
            country: venue.country,
            location: venue.location,
            other_names: venue.other_names,
            latitude: venue.latitude&.round(6),
            longitude: venue.longitude&.round(6),
            shows_count: venue.shows_count,
            first_show: first_show&.date&.iso8601,
            last_show: last_show&.date&.iso8601,
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
