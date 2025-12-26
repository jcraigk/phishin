module Mcp
  module Tools
    class GetSong < MCP::Tool
      description "Get detailed information about a Phish song including performance history. " \
                  "Returns song metadata and a list of performances with dates, venues, " \
                  "durations, and likes for drilling down with get_show."

      input_schema(
        properties: {
          slug: { type: "string", description: "Song slug (e.g., 'tweezer', 'you-enjoy-myself')" },
          sort_by: {
            type: "string",
            enum: %w[date likes duration random],
            description: "Sort performances by date (default), likes, duration, or random"
          },
          sort_order: {
            type: "string",
            enum: %w[asc desc],
            description: "Sort order: asc or desc (default: desc)"
          },
          limit: { type: "integer", description: "Max performances to return (default: 25)" }
        },
        required: [ "slug" ]
      )

      EXCLUDED_SETS = %w[S P].freeze

      class << self
        def call(slug:, sort_by: "date", sort_order: "desc", limit: 25)
          song = Song.find_by(slug:)
          return error_response("Song not found") unless song

          tracks = Track.joins(:show, :songs)
                        .where(songs: { id: song.id })
                        .where.not(set: EXCLUDED_SETS)
                        .where(exclude_from_stats: false)
                        .includes(show: :venue)

          tracks = apply_sort(tracks, sort_by, sort_order)
          tracks = tracks.limit(limit)

          performances = tracks.map do |track|
            {
              date: track.show.date.iso8601,
              venue: track.show.venue_name,
              location: track.show.venue&.location,
              duration_ms: track.duration,
              duration_display: format_duration(track.duration),
              likes: track.likes_count,
              set: track.set
            }
          end

          first_track = Track.joins(:show, :songs)
                             .where(songs: { id: song.id })
                             .where.not(set: EXCLUDED_SETS)
                             .order("shows.date ASC")
                             .first

          last_track = Track.joins(:show, :songs)
                            .where(songs: { id: song.id })
                            .where.not(set: EXCLUDED_SETS)
                            .order("shows.date DESC")
                            .first

          result = {
            title: song.title,
            slug: song.slug,
            original: song.original,
            artist: song.artist,
            alias: song.alias,
            times_played: song.tracks_count,
            first_played: first_track&.show&.date&.iso8601,
            last_played: last_track&.show&.date&.iso8601,
            performances:
          }

          MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
        end

        private

        def apply_sort(scope, sort_by, sort_order)
          direction = sort_order == "asc" ? :asc : :desc

          case sort_by
          when "likes"
            scope.order(likes_count: direction)
          when "duration"
            scope.order(duration: direction)
          when "random"
            scope.order(Arel.sql("RANDOM()"))
          else
            scope.order("shows.date #{direction}")
          end
        end

        def format_duration(ms)
          return "0:00" unless ms&.positive?

          total_seconds = ms / 1000
          minutes = total_seconds / 60
          seconds = total_seconds % 60
          "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], is_error: true)
        end
      end
    end
  end
end
