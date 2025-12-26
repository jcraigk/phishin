class McpServer
  EXCLUDED_SETS = %w[S P].freeze

  class StatsTool < MCP::Tool
    tool_name "stats"

    description "Statistical analysis of Phish performances. Supports gaps (bustouts), " \
                "transitions, durations, venue patterns, set positions, predictions, " \
                "streaks, era comparisons, covers, geographic patterns, and co-occurrence."

    input_schema(
      properties: {
        stat_type: {
          type: "string",
          enum: %w[gaps transitions durations venue_patterns set_positions predictions streaks era_comparison covers geographic co_occurrence],
          description: "Type of statistic to compute"
        },
        song_slug: { type: "string", description: "Song slug for song-specific analysis" },
        song_b_slug: { type: "string", description: "Second song slug for co-occurrence comparison" },
        venue_slug: { type: "string", description: "Venue slug for venue-specific analysis" },
        year: { type: "integer", description: "Filter to specific year" },
        year_range: { type: "array", items: { type: "integer" }, description: "Filter to year range [start, end]" },
        tour_slug: { type: "string", description: "Filter to specific tour" },
        state: { type: "string", description: "US state code for geographic analysis" },
        min_gap: { type: "integer", description: "Minimum show gap for bustout queries" },
        position: { type: "string", enum: %w[opener closer encore], description: "Set position filter" },
        direction: { type: "string", enum: %w[before after], description: "Transition direction" },
        cover_type: { type: "string", enum: %w[frequency ratio by_artist], description: "Cover analysis type" },
        geo_type: { type: "string", enum: %w[state_frequency never_played state_debuts], description: "Geographic analysis type" },
        compare_to: { type: "object", description: "Second era for comparison (year or year_range)" },
        limit: { type: "integer", description: "Limit results (default: 25)" }
      },
      required: [ "stat_type" ]
    )

    class << self
      def call(stat_type:, **options)
        result = PerformanceAnalysisService.call(
          analysis_type: stat_type,
          filters: options.compact,
          log_call: true
        )

        if result[:error]
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{result[:error]}" } ], is_error: true)
        else
          MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
        end
      end
    end
  end

  class GetSongTool < MCP::Tool
    tool_name "get_song"

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

  class GetVenueTool < MCP::Tool
    tool_name "get_venue"

    description "Get detailed information about a venue including show history. " \
                "Returns venue metadata and a list of shows with dates, likes, " \
                "and duration for drilling down with get_show."

    input_schema(
      properties: {
        slug: { type: "string", description: "Venue slug (e.g., 'madison-square-garden')" },
        sort_by: {
          type: "string",
          enum: %w[date likes duration random],
          description: "Sort shows by date (default), likes, duration, or random"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc or desc (default: desc)"
        },
        limit: { type: "integer", description: "Max shows to return (default: 25)" }
      },
      required: [ "slug" ]
    )

    class << self
      def call(slug:, sort_by: "date", sort_order: "desc", limit: 25)
        venue = Venue.find_by(slug:)
        return error_response("Venue not found") unless venue

        shows = Show.where(venue_id: venue.id)
                    .where("duration > 0")

        shows = apply_sort(shows, sort_by, sort_order)
        shows = shows.limit(limit)

        show_list = shows.map do |show|
          {
            date: show.date.iso8601,
            duration_ms: show.duration,
            duration_display: format_duration(show.duration),
            likes: show.likes_count,
            tour: show.tour&.name
          }
        end

        first_show = Show.where(venue_id: venue.id).order(date: :asc).first
        last_show = Show.where(venue_id: venue.id).order(date: :desc).first

        result = {
          name: venue.name,
          slug: venue.slug,
          city: venue.city,
          state: venue.state,
          country: venue.country,
          location: venue.location,
          other_names: venue.other_names,
          latitude: venue.latitude&.round(6),
          longitude: venue.longitude&.round(6),
          shows_count: venue.shows_count,
          first_show: first_show&.date&.iso8601,
          last_show: last_show&.date&.iso8601,
          shows: show_list
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
          scope.order(date: direction)
        end
      end

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

  class GetTourTool < MCP::Tool
    tool_name "get_tour"

    description "Get detailed information about a Phish tour including show history. " \
                "Returns tour metadata and a list of shows with dates, venues, likes, " \
                "and duration for drilling down with get_show."

    input_schema(
      properties: {
        slug: { type: "string", description: "Tour slug (e.g., 'fall-1997', 'summer-2023')" },
        sort_by: {
          type: "string",
          enum: %w[date likes duration random],
          description: "Sort shows by date (default), likes, duration, or random"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc or desc (default: asc for date, desc for others)"
        },
        limit: { type: "integer", description: "Max shows to return (default: all shows on tour)" }
      },
      required: [ "slug" ]
    )

    class << self
      def call(slug:, sort_by: "date", sort_order: nil, limit: nil)
        tour = Tour.find_by(slug:)
        return error_response("Tour not found") unless tour

        shows = Show.where(tour_id: tour.id).includes(:venue)

        sort_order ||= sort_by == "date" ? "asc" : "desc"
        shows = apply_sort(shows, sort_by, sort_order)
        shows = shows.limit(limit) if limit

        show_list = shows.map do |show|
          {
            date: show.date.iso8601,
            venue: show.venue_name,
            location: show.venue&.location,
            duration_ms: show.duration,
            duration_display: format_duration(show.duration),
            likes: show.likes_count
          }
        end

        result = {
          name: tour.name,
          slug: tour.slug,
          starts_on: tour.starts_on.iso8601,
          ends_on: tour.ends_on.iso8601,
          shows_count: tour.shows_count,
          shows: show_list
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
          scope.order(date: direction)
        end
      end

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

  class GetPlaylistTool < MCP::Tool
    tool_name "get_playlist"

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

  class GetShowTool < MCP::Tool
    tool_name "get_show"

    description "Get complete details for a Phish show by date, including setlist, " \
                "venue, tags, and navigation to adjacent shows."

    input_schema(
      properties: {
        date: { type: "string", description: "Show date in YYYY-MM-DD format" }
      },
      required: [ "date" ]
    )

    class << self
      def call(date:)
        result = Mcp::GetShowService.call(date:, log_call: true)

        if result[:error]
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{result[:error]}" } ], is_error: true)
        else
          MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
        end
      end
    end
  end

  class SearchTool < MCP::Tool
    tool_name "search"

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

  def self.instance
    @instance ||= MCP::Server.new(
      name: "phishin",
      version: "1.0.0",
      tools: [ GetPlaylistTool, GetShowTool, GetSongTool, GetTourTool, GetVenueTool, SearchTool, StatsTool ],
      configuration: MCP::Configuration.new(protocol_version: "2024-11-05")
    )
  end
end
