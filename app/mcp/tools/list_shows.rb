module Tools
  class ListShows < MCP::Tool
    tool_name "list_shows"

    description "List Phish shows with optional setlist details. " \
                "Filter by year, tour, venue, or specific date(s). " \
                "Use include_tracks=true for full setlists. " \
                "At least one filter is required. " \
                "Includes public website URLs - include show URLs when listing or referencing specific shows."

    input_schema(
      properties: {
        date: { type: "string", description: "Single show date (YYYY-MM-DD)" },
        dates: {
          type: "array",
          items: { type: "string" },
          description: "Multiple show dates (YYYY-MM-DD format)"
        },
        year: { type: "integer", description: "Filter by year (e.g., 1997)" },
        tour_slug: { type: "string", description: "Filter by tour slug (e.g., 'fall-tour-1997')" },
        venue_slug: { type: "string", description: "Filter by venue slug (e.g., 'madison-square-garden')" },
        include_tracks: {
          type: "boolean",
          description: "Include full setlist with track details (default: false)"
        },
        include_taper_notes: {
          type: "boolean",
          description: "Include taper/source notes (default: false)"
        },
        sort_by: {
          type: "string",
          enum: %w[date likes duration],
          description: "Sort by date (default), likes, or duration"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc (default for date) or desc"
        },
        limit: { type: "integer", description: "Max shows to return (default: 50)" }
      },
      required: []
    )

    class << self
      def call(
        date: nil,
        dates: nil,
        year: nil,
        tour_slug: nil,
        venue_slug: nil,
        include_tracks: false,
        include_taper_notes: false,
        sort_by: "date",
        sort_order: nil,
        limit: 50
      )
        has_filter = date || dates&.any? || year || tour_slug || venue_slug
        return error_response("At least one filter required: date, dates, year, tour_slug, or venue_slug") unless has_filter

        shows = build_query(date, dates, year, tour_slug, venue_slug, include_tracks)
        return error_response("No shows found") if shows.empty?

        sort_order ||= sort_by == "date" ? "asc" : "desc"
        shows = apply_sort(shows, sort_by, sort_order)
        shows = shows.limit(limit) if limit && !date

        show_list = shows.map { |show| build_show_data(show, include_tracks, include_taper_notes) }

        result = if date && show_list.size == 1
                   show_list.first
        else
                   {
                     total: show_list.size,
                     filters: { date:, dates:, year:, tour_slug:, venue_slug: }.compact,
                     shows: show_list
                   }
        end

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      private

      def build_query(date, dates, year, tour_slug, venue_slug, include_tracks)
        shows = Show.includes(:venue, :tour)

        if include_tracks
          shows = shows.includes(
            tracks: [ :songs, { track_tags: :tag, songs_tracks: {} } ],
            show_tags: :tag
          )
        end

        shows = shows.where(date:) if date
        shows = shows.where(date: dates) if dates&.any?
        shows = shows.where("EXTRACT(YEAR FROM date) = ?", year) if year
        shows = apply_tour_filter(shows, tour_slug) if tour_slug
        shows = apply_venue_filter(shows, venue_slug) if venue_slug

        shows
      end

      def build_show_data(show, include_tracks, include_taper_notes)
        data = {
          date: show.date.iso8601,
          url: show.url,
          venue: include_tracks ? venue_data(show) : show.venue_name,
          location: show.venue&.location,
          tour: show.tour&.name,
          duration_ms: show.duration,
          duration_display: McpHelpers.format_duration(show.duration),
          likes: show.likes_count,
          audio_status: show.audio_status
        }

        if include_tracks
          data[:tags] = show.show_tags.map { |st| tag_data(st) }
          data[:tracks] = tracks_data(show)
        end

        data[:taper_notes] = show.taper_notes if include_taper_notes

        data
      end

      def venue_data(show)
        {
          name: show.venue_name,
          slug: show.venue.slug,
          url: show.venue.url,
          city: show.venue.city,
          state: show.venue.state,
          country: show.venue.country
        }
      end

      def tag_data(show_tag)
        {
          name: show_tag.tag.name,
          slug: show_tag.tag.slug,
          notes: show_tag.notes
        }
      end

      def tracks_data(show)
        show.tracks.sort_by(&:position).map do |track|
          songs_track = track.songs_tracks.first
          {
            position: track.position,
            title: track.title,
            slug: track.slug,
            url: track.url,
            set: track.set,
            set_name: track.set_name,
            duration_ms: track.duration,
            duration_display: McpHelpers.format_duration(track.duration),
            songs: track.songs.map { |s| { title: s.title, slug: s.slug, url: s.url } },
            tags: track.track_tags.map { |tt| { name: tt.tag.name, notes: tt.notes } },
            likes_count: track.likes_count,
            gap: songs_track && {
              previous: songs_track.previous_performance_gap,
              next: songs_track.next_performance_gap,
              previous_slug: songs_track.previous_performance_slug,
              next_slug: songs_track.next_performance_slug
            }
          }
        end
      end

      def apply_tour_filter(shows, tour_slug)
        tour = Tour.find_by(slug: tour_slug)
        return shows.none unless tour
        shows.where(tour_id: tour.id)
      end

      def apply_venue_filter(shows, venue_slug)
        venue = Venue.find_by(slug: venue_slug)
        return shows.none unless venue
        shows.where(venue_id: venue.id)
      end

      def apply_sort(scope, sort_by, sort_order)
        direction = sort_order == "asc" ? :asc : :desc

        case sort_by
        when "likes"
          scope.order(likes_count: direction)
        when "duration"
          scope.order(duration: direction)
        else
          scope.order(date: direction)
        end
      end

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
