module Mcp
  module Tools
    class Search < MCP::Tool
      description "Search across Phish shows, songs, venues, tags, and playlists."

      input_schema(
        properties: {
          query: { type: "string", description: "Search query (min 2 characters)" },
          limit: { type: "integer", description: "Max results per category (default: 25)" }
        },
        required: ["query"]
      )

      class << self
        def call(query:, limit: 25)
          result = ::Mcp::SearchService.call(
            query: query,
            limit: limit,
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
