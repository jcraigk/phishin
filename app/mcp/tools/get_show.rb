module Mcp
  module Tools
    class GetShow < MCP::Tool
      description "Get complete details for a Phish show by date, including setlist, " \
                  "venue, tags, and navigation to adjacent shows."

      input_schema(
        properties: {
          date: { type: "string", description: "Show date in YYYY-MM-DD format" }
        },
        required: [ "date" ]
      )

      class << self
        def call(date:)
          result = ::Mcp::GetShowService.call(date:, log_call: true)

          if result[:error]
            MCP::Tool::Response.new([ { type: "text", text: "Error: #{result[:error]}" } ], is_error: true)
          else
            MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
          end
        end
      end
    end
  end
end
