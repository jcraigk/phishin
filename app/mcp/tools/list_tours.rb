module Tools
  class ListTours < MCP::Tool
    tool_name "list_tours"

    description Descriptions::BASE[:list_tours]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(
      properties: {
        year: { type: "integer", description: "Filter tours by year (e.g., 1997)" }
      },
      required: []
    )

    class << self
      def call(year: nil)
        result = fetch_tours(year)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_tours(year)
        cache_key = McpHelpers.cache_key_for_collection("tours", { year: })

        Rails.cache.fetch(cache_key) do
          tours = Tour.all

          if year
            tours = tours.where("EXTRACT(YEAR FROM starts_on) = ? OR EXTRACT(YEAR FROM ends_on) = ?", year, year)
          end

          tours = tours.order(starts_on: :asc)

          tour_list = tours.map do |tour|
            {
              name: tour.name,
              slug: tour.slug,
              starts_on: tour.starts_on.iso8601,
              ends_on: tour.ends_on.iso8601,
              shows_count: tour.shows_count
            }
          end

          {
            total: tour_list.size,
            tours: tour_list
          }
        end
      end
    end
  end
end
