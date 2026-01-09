module Tools
  class GetVenue < MCP::Tool
    tool_name "get_venue"

    description Descriptions::BASE[:get_venue]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Venue slug (e.g., 'madison-square-garden'). Omit for random venue." },
        random: { type: "boolean", description: "Set to true for a random venue (ignores slug)" }
      },
      required: []
    )

    class << self
      def call(slug: nil, random: false)
        venue = if random || slug.nil?
          Venue.where("shows_count > 0").order(Arel.sql("RANDOM()")).first
        else
          Venue.find_by(slug:)
        end
        return error_response("Venue not found") unless venue

        result = fetch_venue_data(venue)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_venue_data(venue)
        Rails.cache.fetch(McpHelpers.cache_key_for_resource("venues", venue.slug)) do
          first_show = Show.where(venue_id: venue.id).order(date: :asc).first
          last_show = Show.where(venue_id: venue.id).order(date: :desc).first

          {
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
        end
      end

      private

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
