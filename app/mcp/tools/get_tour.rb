module Tools
  class GetTour < MCP::Tool
    tool_name "get_tour"

    description "Get detailed information about a Phish tour. " \
                "Returns tour metadata including date range and show count. " \
                "Use list_shows with tour_slug to get the list of shows on this tour. " \
                "Format dates readably (e.g., 'Jul 4, 2023')."

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

        result = {
          name: tour.name,
          slug: tour.slug,
          starts_on: tour.starts_on.iso8601,
          ends_on: tour.ends_on.iso8601,
          shows_count: tour.shows_count
        }

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
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
