module Mcp
  module Tools
    class GetPlaylist < MCP::Tool
      description "Get detailed information about a user-created playlist. " \
                  "Returns playlist metadata and track listing with show dates and durations."

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
              song_slug: track.songs.first&.slug,
              date: track.show.date.iso8601,
              venue: track.show.venue_name,
              location: track.show.venue&.location,
              duration_ms: track.duration,
              duration_display: format_duration(track.duration),
              set: track.set
            }
          end

          result = {
            name: playlist.name,
            slug: playlist.slug,
            description: playlist.description,
            duration_ms: playlist.duration,
            duration_display: format_duration(playlist.duration),
            track_count: tracks.size,
            tracks: track_list
          }

          MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
        end

        private

        def format_duration(ms)
          return "0:00" unless ms&.positive?

          total_seconds = ms / 1000
          hours = total_seconds / 3600
          minutes = (total_seconds % 3600) / 60
          seconds = total_seconds % 60

          if hours > 0
            "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
          else
            "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
          end
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], is_error: true)
        end
      end
    end
  end
end
