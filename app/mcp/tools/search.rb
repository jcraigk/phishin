module Tools
  class Search < MCP::Tool
    tool_name "search"

    description "Search across Phish shows, songs, venues, tours, tags, and playlists. " \
                "Returns results with public website URLs for each item - always share these links with users!"

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
          songs: raw[:songs]&.first(limit)&.map { |s| serialize_song(s) } || [],
          venues: raw[:venues]&.first(limit)&.map { |v| serialize_venue(v) } || [],
          tours: raw[:tours]&.first(limit)&.map { |t| serialize_tour(t) } || [],
          tags: raw[:tags]&.first(limit)&.map { |t| serialize(:tag, t, :name, :slug, :description, :shows_count, :tracks_count) } || [],
          playlists: raw[:playlists]&.first(limit)&.map { |p| serialize_playlist(p) } || []
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
          url: show.url,
          venue_name: show.venue_name,
          location: show.venue&.location,
          tour_name: show.tour&.name,
          audio_status: show.audio_status,
          duration_ms: show.duration,
          likes_count: show.likes_count,
          tags: show.show_tags.map { |st| st.tag.name }
        }
      end

      def serialize_song(song)
        {
          type: :song,
          title: song.title,
          slug: song.slug,
          url: song.url,
          original: song.original,
          artist: song.artist,
          tracks_count: song.tracks_count
        }
      end

      def serialize_venue(venue)
        {
          type: :venue,
          name: venue.name,
          slug: venue.slug,
          url: venue.url,
          location: venue.location,
          shows_count: venue.shows_count
        }
      end

      def serialize_playlist(playlist)
        {
          type: :playlist,
          name: playlist.name,
          slug: playlist.slug,
          url: playlist.url,
          description: playlist.description,
          track_count: playlist.playlist_tracks.size,
          duration_ms: playlist.duration
        }
      end

      def serialize_tour(tour)
        {
          type: :tour,
          name: tour.name,
          slug: tour.slug,
          starts_on: tour.starts_on.iso8601,
          ends_on: tour.ends_on.iso8601,
          shows_count: tour.shows_count
        }
      end

      def serialize(type, obj, *attrs)
        { type: }.merge(attrs.to_h { |a| [ a, obj.public_send(a) ] })
      end

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
