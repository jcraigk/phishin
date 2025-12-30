module Tools
  class GetTour < MCP::Tool
    tool_name "get_tour"

    description Descriptions::BASE[:get_tour]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Tour slug (e.g., 'fall-tour-1997', 'summer-tour-2023'). Omit for random tour." },
        random: { type: "boolean", description: "Set to true for a random tour (ignores slug)" }
      },
      required: []
    )

    class << self
      def call(slug: nil, random: false)
        tour = if random || slug.nil?
          Tour.order(Arel.sql("RANDOM()")).first
        else
          Tour.find_by(slug:)
        end
        return error_response("Tour not found") unless tour

        result = fetch_tour_data(tour)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_tour_data(tour)
        Rails.cache.fetch(McpHelpers.cache_key_for_resource("tours", tour.slug)) do
          {
            name: tour.name,
            slug: tour.slug,
            starts_on: tour.starts_on.iso8601,
            ends_on: tour.ends_on.iso8601,
            shows_count: tour.shows_count
          }
        end
      end

      private

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
