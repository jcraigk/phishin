module Mcp
  module Tools
    class Search < MCP::Tool
      description "Search across Phish shows, songs, venues, tags, and playlists."

      input_schema(
        properties: {
          query: { type: "string", description: "Search query (min 2 characters)" },
          limit: { type: "integer", description: "Max results per category (default: 25)" }
        },
        required: [ "query" ]
      )

      class << self
        def call(query:, limit: 25)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return error_response("Query must be at least 2 characters") if query.to_s.length < 2

          raw = ::SearchService.call(term: query, scope: "all") || {}
          results = {
            query:,
            shows: serialize_shows(raw, limit),
            songs: raw[:songs]&.first(limit)&.map { |s| serialize(:song, s, :title, :slug, :original, :artist, :tracks_count) } || [],
            venues: raw[:venues]&.first(limit)&.map { |v| serialize(:venue, v, :name, :slug, :location, :shows_count) } || [],
            tags: raw[:tags]&.first(limit)&.map { |t| serialize(:tag, t, :name, :slug, :description, :shows_count, :tracks_count) } || [],
            playlists: raw[:playlists]&.first(limit)&.map { |p| serialize(:playlist, p, :name, :slug, :description).merge(track_count: p.playlist_tracks.size, duration_ms: p.duration) } || []
          }
          results[:total_results] = results.except(:query).values.sum(&:count)
          log_call(query, limit, results, start_time)

          MCP::Tool::Response.new([ { type: "text", text: results.to_json } ])
        end

        private

        def log_call(query, limit, results, start_time)
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          McpToolCall.log_call(tool_name: "search", parameters: { query:, limit: }, result: results, duration_ms:)
        end

        def serialize_shows(raw, limit)
          shows = []
          shows << serialize_show(raw[:exact_show]) if raw[:exact_show]
          raw[:other_shows]&.first(limit)&.each { |s| shows << serialize_show(s) }
          shows.first(limit)
        end

        def serialize_show(show)
          {
            type: :show,
            date: show.date.iso8601,
            venue_name: show.venue_name,
            location: show.venue&.location,
            tour_name: show.tour&.name,
            audio_status: show.audio_status,
            duration_ms: show.duration,
            likes_count: show.likes_count,
            tags: show.show_tags.map { |st| st.tag.name }
          }
        end

        def serialize(type, obj, *attrs)
          { type: }.merge(attrs.to_h { |a| [ a, obj.public_send(a) ] })
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], is_error: true)
        end
      end
    end
  end
end
