module Tools
  class GetTour < MCP::Tool
    tool_name "get_tour"

    description Descriptions::BASE[:get_tour]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Tour slug (e.g., 'fall-tour-1997', 'summer-tour-2023')" }
      },
      required: [ "slug" ]
    )

    class << self
      def call(slug:)
        tour = Tour.find_by(slug:)
        return tour_not_found_error(slug) unless tour

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

      def tour_not_found_error(slug)
        all_slugs = Tour.pluck(:slug)
        checker = DidYouMean::SpellChecker.new(dictionary: all_slugs)
        suggestions = checker.correct(slug)

        message = "Tour not found for slug: #{slug}"
        if suggestions.any?
          message += ". Did you mean: #{suggestions.first(3).join(', ')}?"
        end
        message += " Use list_tours to see all available tours."

        error_response(message)
      end

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
