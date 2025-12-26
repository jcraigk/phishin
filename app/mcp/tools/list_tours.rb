module Tools
  class ListTours < MCP::Tool
    tool_name "list_tours"

    description "List all Phish tours with optional year filtering. " \
                "Returns tour names, slugs, and date ranges. " \
                "Use this to discover available tours before calling get_tour."

    input_schema(
      properties: {
        year: { type: "integer", description: "Filter tours by year (e.g., 1997)" }
      },
      required: []
    )

    class << self
      def call(year: nil)
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

        result = {
          total: tour_list.size,
          tours: tour_list
        }

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end
    end
  end
end

