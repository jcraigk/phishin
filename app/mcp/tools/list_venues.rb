module Tools
  class ListVenues < MCP::Tool
    tool_name "list_venues"

    description Descriptions::BASE[:list_venues]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

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
      }
    )

    class << self
      def call(city: nil, state: nil, country: nil, sort_by: "name", sort_order: nil, limit: 50)
        sort_order ||= sort_by == "shows_count" ? "desc" : "asc"

        result = fetch_venues(city, state, country, sort_by, sort_order, limit)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_venues(city, state, country, sort_by, sort_order, limit)
        cache_key = McpHelpers.cache_key_for_collection("venues", {
          city:, state:, country:, sort_by:, sort_order:, limit:
        })

        Rails.cache.fetch(cache_key) do
          venues = Venue.all

          venues = venues.where("city ILIKE ?", "%#{city}%") if city
          venues = venues.where("state ILIKE ?", "%#{state}%") if state
          venues = venues.where("country ILIKE ?", "%#{country}%") if country

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

          {
            total: venue_list.size,
            filters: { city:, state:, country: }.compact,
            venues: venue_list
          }
        end
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
