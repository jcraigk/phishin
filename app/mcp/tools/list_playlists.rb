module Tools
  class ListPlaylists < MCP::Tool
    tool_name "list_playlists"

    description Descriptions::BASE[:list_playlists]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(
      properties: {
        sort_by: {
          type: "string",
          enum: %w[name likes_count tracks_count duration updated_at random],
          description: "Sort by name, likes_count (default), tracks_count, duration, updated_at, or random"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc or desc (default)"
        },
        limit: { type: "integer", description: "Max playlists to return (default: 50)" }
      }
    )

    class << self
      def call(sort_by: "likes_count", sort_order: "desc", limit: 50)
        result = fetch_playlists(sort_by, sort_order, limit)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_playlists(sort_by, sort_order, limit)
        if sort_by == "random"
          build_playlists_result(sort_by, sort_order, limit)
        else
          cache_key = McpHelpers.cache_key_for_collection("playlists", {
            sort_by:, sort_order:, limit:
          })

          Rails.cache.fetch(cache_key) do
            build_playlists_result(sort_by, sort_order, limit)
          end
        end
      end

      def build_playlists_result(sort_by, sort_order, limit)
        playlists = Playlist.published.includes(:user)
        playlists = apply_sort(playlists, sort_by, sort_order)
        playlists = playlists.limit(limit)

        playlist_list = playlists.map { |playlist| build_playlist_data(playlist) }

        {
          total: playlist_list.size,
          playlists: playlist_list
        }
      end

      private

      def build_playlist_data(playlist)
        {
          name: playlist.name,
          slug: playlist.slug,
          url: playlist.url,
          description: playlist.description,
          duration_ms: playlist.duration,
          duration_display: McpHelpers.format_duration(playlist.duration),
          tracks_count: playlist.playlist_tracks.size,
          likes_count: playlist.likes_count,
          author: playlist.user&.username,
          updated_at: playlist.updated_at.iso8601
        }
      end

      def apply_sort(scope, sort_by, sort_order)
        direction = sort_order == "asc" ? :asc : :desc

        case sort_by
        when "likes_count"
          scope.order(likes_count: direction)
        when "tracks_count"
          scope.order(tracks_count: direction)
        when "duration"
          scope.order(duration: direction)
        when "updated_at"
          scope.order(updated_at: direction)
        when "random"
          scope.order(Arel.sql("RANDOM()"))
        else
          scope.order(name: direction)
        end
      end
    end
  end
end
