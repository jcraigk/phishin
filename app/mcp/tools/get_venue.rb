module Tools
  class GetVenue < MCP::Tool
    tool_name "get_venue"

    description "Get detailed information about a venue. " \
                "Returns venue metadata including location, show count, and date range. " \
                "Use list_shows with venue_slug to get the list of shows at this venue. " \
                "DISPLAY: In markdown, link the venue name to its url field. " \
                "Example: [Madison Square Garden](url). " \
                "Format dates readably (e.g., 'Jul 4, 2023')."

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Venue slug (e.g., 'madison-square-garden')" }
      },
      required: [ "slug" ]
    )

    class << self
      def call(slug:)
        venue = Venue.find_by(slug:)
        return venue_not_found_error(slug) unless venue

        first_show = Show.where(venue_id: venue.id).order(date: :asc).first
        last_show = Show.where(venue_id: venue.id).order(date: :desc).first

        result = {
          name: venue.name,
          slug: venue.slug,
          url: venue.url,
          city: venue.city,
          state: venue.state,
          country: venue.country,
          location: venue.location,
          other_names: venue.other_names,
          latitude: venue.latitude&.round(6),
          longitude: venue.longitude&.round(6),
          shows_count: venue.shows_count,
          first_show: first_show&.date&.iso8601,
          last_show: last_show&.date&.iso8601
        }

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      private

      def venue_not_found_error(slug)
        all_slugs = Venue.pluck(:slug)
        checker = DidYouMean::SpellChecker.new(dictionary: all_slugs)
        suggestions = checker.correct(slug)

        message = "Venue not found for slug: #{slug}"
        if suggestions.any?
          message += ". Did you mean: #{suggestions.first(3).join(', ')}?"
        end
        message += " Use list_venues to discover venue slugs."

        error_response(message)
      end

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
