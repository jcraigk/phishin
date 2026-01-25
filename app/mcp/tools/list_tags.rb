module Tools
  class ListTags < MCP::Tool
    tool_name "list_tags"

    description Descriptions::BASE[:list_tags]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(properties: {})

    class << self
      def call
        result = fetch_tags
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_tags
        Rails.cache.fetch(McpHelpers.cache_key_for_custom("tags")) do
          tags = Tag.order(priority: :asc)

          tag_list = tags.map do |tag|
            {
              name: tag.name,
              slug: tag.slug,
              group: tag.group,
              description: tag.description,
              shows_count: tag.shows_count,
              tracks_count: tag.tracks_count
            }
          end

          { total: tag_list.size, tags: tag_list }
        end
      end
    end
  end
end
