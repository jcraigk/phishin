module Tools
  class ListSongs < MCP::Tool
    tool_name "list_songs"

    description "List Phish songs with optional filtering and sorting. " \
                "Returns song names, slugs, play counts, and cover/original status. " \
                "Use this to discover songs before calling get_song for detailed performance history."

    input_schema(
      properties: {
        song_type: {
          type: "string",
          enum: %w[all original cover],
          description: "Filter by song type: all (default), original, or cover"
        },
        sort_by: {
          type: "string",
          enum: %w[name times_played],
          description: "Sort by name (default) or times_played"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc (default for name) or desc (default for times_played)"
        },
        min_plays: {
          type: "integer",
          description: "Minimum number of performances (filters out rarely played songs)"
        },
        limit: { type: "integer", description: "Max songs to return (default: 50)" }
      },
      required: []
    )

    class << self
      def call(song_type: "all", sort_by: "name", sort_order: nil, min_plays: nil, limit: 50)
        songs = Song.all

        case song_type
        when "original"
          songs = songs.where(original: true)
        when "cover"
          songs = songs.where(original: false)
        end

        songs = songs.where("tracks_count >= ?", min_plays) if min_plays

        sort_order ||= sort_by == "times_played" ? "desc" : "asc"
        direction = sort_order == "desc" ? :desc : :asc

        songs = case sort_by
        when "times_played"
          songs.order(tracks_count: direction)
        else
          songs.order(title: direction)
        end

        songs = songs.limit(limit)

        song_list = songs.map do |song|
          {
            title: song.title,
            slug: song.slug,
            original: song.original,
            artist: song.artist,
            times_played: song.tracks_count,
            url: song.url
          }
        end

        result = {
          total: song_list.size,
          songs: song_list
        }

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end
    end
  end
end

