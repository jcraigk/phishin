module Mcp
  module Tools
    class GetShow < MCP::Tool
      description "Get complete details for a Phish show by date, including setlist, " \
                  "venue, tags, and navigation to adjacent shows."

      input_schema(
        properties: {
          date: { type: "string", description: "Show date in YYYY-MM-DD format" },
          include_tracks: { type: "boolean", description: "Include track listing (default: true)" },
          include_gaps: { type: "boolean", description: "Include gap data for songs (default: true)" }
        },
        required: ["date"]
      )

      class << self
        def call(date:, include_tracks: true, include_gaps: true)
          result = ::Mcp::GetShowService.call(
            date: date,
            include_tracks: include_tracks,
            include_gaps: include_gaps,
            log_call: true
          )

          if result[:error]
            MCP::Tool::Response.new([{ type: "text", text: "Error: #{result[:error]}" }], is_error: true)
          else
            MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
          end
        end
      end
    end
  end
end
