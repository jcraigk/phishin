module Tools
  class GetPlaylist < MCP::Tool
    tool_name "get_playlist"

    description "Get detailed information about a user-created playlist. " \
                "Returns playlist metadata and track listing with show dates and durations. " \
                "Includes public website URLs for the playlist and each track - always share these links with users!"

    input_schema(
      properties: {
        slug: { type: "string", description: "Playlist slug" }
      },
      required: [ "slug" ]
    )

    class << self
      def call(slug:)
        playlist = Playlist.published.find_by(slug:)
        return error_response("Playlist not found") unless playlist

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

        result = {
          name: playlist.name,
          slug: playlist.slug,
          url: playlist.url,
          description: playlist.description,
          duration_ms: playlist.duration,
          duration_display: McpHelpers.format_duration(playlist.duration),
          track_count: tracks.size,
          tracks: track_list
        }

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      private

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
