module Tools
  class GetPlaylist < MCP::Tool
    tool_name "get_playlist"

    description "Get detailed information about a user-created playlist. " \
                "Returns playlist metadata and track listing with show dates and durations. " \
                "DISPLAY: In markdown, link playlist name to playlist url and track titles to track url. " \
                "Example: | [Tweezer](track_url) | [Jul 4, 2023](show_url) |. " \
                "Format dates readably (e.g., 'Jul 4, 2023'). " \
                "Display a maximum of 10 tracks in chat."

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Playlist slug (omit for random playlist)" }
      },
      required: []
    )

    class << self
      def call(slug: nil)
        playlist = if slug
          Playlist.published.find_by(slug:)
        else
          Playlist.published.order(Arel.sql("RANDOM()")).first
        end
        return error_response("Playlist not found") unless playlist

        result = fetch_playlist_data(playlist, cache: slug.present?)
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_playlist_data(playlist, cache: true)
        if cache
          Rails.cache.fetch(McpHelpers.cache_key_for_resource("playlists", playlist.slug)) do
            build_playlist_data(playlist)
          end
        else
          build_playlist_data(playlist)
        end
      end

      def build_playlist_data(playlist)
        tracks = playlist.playlist_tracks.order(:position).includes(track: { show: :venue })

        track_list = tracks.map do |pt|
          track = pt.track
          {
            position: pt.position,
            title: track.title,
            slug: track.slug,
            song_slug: track.songs.first&.slug,
            date: track.show.date.iso8601,
            venue: track.show.venue_name,
            location: track.show.venue&.location,
            duration_ms: track.duration,
            duration_display: McpHelpers.format_duration(track.duration),
            set: track.set,
            url: track.url
          }
        end

        {
          name: playlist.name,
          slug: playlist.slug,
          url: playlist.url,
          description: playlist.description,
          duration_ms: playlist.duration,
          duration_display: McpHelpers.format_duration(playlist.duration),
          track_count: tracks.size,
          tracks: track_list
        }
      end

      private

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
