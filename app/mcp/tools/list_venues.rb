module Tools
  class ListVenues < MCP::Tool
    tool_name "list_venues"

    description "List Phish venues with optional geographic filtering. " \
                "Returns venue names, slugs, locations, and show counts. " \
                "Use this to discover venue slugs before calling get_venue. " \
                "DISPLAY: In markdown, link venue names to their url field. " \
                "Example: [Madison Square Garden](url)."

    input_schema(
      properties: {
        city: { type: "string", description: "Filter by city name" },
        state: { type: "string", description: "Filter by state (e.g., 'NY', 'California')" },
        country: { type: "string", description: "Filter by country (e.g., 'USA', 'Germany')" },
        sort_by: {
          type: "string",
          enum: %w[name shows_count],
          description: "Sort by name (default) or shows_count"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc (default for name) or desc (default for shows_count)"
        },
        limit: { type: "integer", description: "Max venues to return (default: 50)" }
      },
      required: []
    )

    class << self
      def call(city: nil, state: nil, country: nil, sort_by: "name", sort_order: nil, limit: 50)
        venues = Venue.all

        venues = venues.where("city ILIKE ?", "%#{city}%") if city
        venues = venues.where("state ILIKE ?", "%#{state}%") if state
        venues = venues.where("country ILIKE ?", "%#{country}%") if country

        sort_order ||= sort_by == "shows_count" ? "desc" : "asc"
        venues = apply_sort(venues, sort_by, sort_order)
        venues = venues.limit(limit) if limit

        venue_list = venues.map do |venue|
          {
            name: venue.name,
            slug: venue.slug,
            url: venue.url,
            city: venue.city,
            state: venue.state,
            country: venue.country,
            location: venue.location,
            shows_count: venue.shows_count
          }
        end

        result = {
          total: venue_list.size,
          filters: { city:, state:, country: }.compact,
          venues: venue_list
        }

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      private

      def apply_sort(scope, sort_by, sort_order)
        direction = sort_order == "asc" ? :asc : :desc

        case sort_by
        when "shows_count"
          scope.order(shows_count: direction)
        else
          scope.order(name: direction)
        end
      end
    end
  end
end
