module Tools
  class ListTracks < MCP::Tool
    tool_name "list_tracks"

    description Descriptions::BASE[:list_tracks]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        sort_by: {
          type: "string",
          enum: %w[date likes duration random],
          description: "Sort by date (default), likes, duration, or random. Use 'random' for random track discovery."
        },
        song_slug: { type: "string", description: "Filter by song slug (e.g., 'tweezer')" },
        venue_slug: { type: "string", description: "Filter by venue slug (e.g., 'madison-square-garden')" },
        show_date: { type: "string", description: "Filter by show date (YYYY-MM-DD)" },
        year: { type: "integer", description: "Filter by year (e.g., 1997)" },
        tag_slug: { type: "string", description: "Filter by tag slug (e.g., 'jamcharts')" },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc or desc (default: desc for likes/duration, asc for date)"
        },
        limit: { type: "integer", description: "Max tracks to return (default: 25, max 10 for random without filters)" }
      },
      required: []
    )

    class << self
      def call(
        song_slug: nil,
        venue_slug: nil,
        show_date: nil,
        year: nil,
        tag_slug: nil,
        sort_by: "date",
        sort_order: nil,
        limit: 25
      )
        has_filter = song_slug || venue_slug || show_date || year || tag_slug
        is_random = sort_by == "random"

        unless has_filter || is_random
          return error_response("At least one filter required (song_slug, venue_slug, show_date, year, tag_slug) OR use sort_by='random'")
        end

        sort_order ||= sort_by == "date" ? "asc" : "desc"
        limit = [ limit || 25, 10 ].min if is_random && !has_filter

        result = fetch_tracks(song_slug, venue_slug, show_date, year, tag_slug, sort_by, sort_order, limit)
        return error_response("No tracks found") unless result

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_tracks(song_slug, venue_slug, show_date, year, tag_slug, sort_by, sort_order, limit)
        if sort_by == "random"
          build_tracks_result(song_slug, venue_slug, show_date, year, tag_slug, sort_by, sort_order, limit)
        else
          cache_key = McpHelpers.cache_key_for_collection("tracks", {
            song_slug:, venue_slug:, show_date:, year:, tag_slug:, sort_by:, sort_order:, limit:
          })

          Rails.cache.fetch(cache_key) do
            build_tracks_result(song_slug, venue_slug, show_date, year, tag_slug, sort_by, sort_order, limit)
          end
        end
      end

      def build_tracks_result(song_slug, venue_slug, show_date, year, tag_slug, sort_by, sort_order, limit)
        tracks = build_query(song_slug, venue_slug, show_date, year, tag_slug)
        return nil if tracks.empty?

        tracks = apply_sort(tracks, sort_by, sort_order)
        tracks = tracks.limit(limit) if limit

        track_list = tracks.map { |track| build_track_data(track) }

        {
          total: track_list.size,
          filters: { song_slug:, venue_slug:, show_date:, year:, tag_slug: }.compact,
          tracks: track_list
        }
      end

      private

      def build_query(song_slug, venue_slug, show_date, year, tag_slug)
        tracks = Track.includes(:show, :songs, :tags, show: :venue)
                      .where.not(set: %w[S P])
                      .where(exclude_from_stats: false)

        tracks = apply_song_filter(tracks, song_slug) if song_slug
        tracks = apply_venue_filter(tracks, venue_slug) if venue_slug
        tracks = tracks.joins(:show).where(shows: { date: show_date }) if show_date
        tracks = tracks.joins(:show).where("EXTRACT(YEAR FROM shows.date) = ?", year) if year
        tracks = apply_tag_filter(tracks, tag_slug) if tag_slug

        tracks
      end

      def build_track_data(track)
        songs_track = track.songs_tracks.first
        {
          date: track.show.date.iso8601,
          show_url: track.show.url,
          track_url: track.url,
          title: track.title,
          slug: track.slug,
          set: track.set,
          set_name: track.set_name,
          duration_ms: track.duration,
          duration_display: McpHelpers.format_duration(track.duration),
          likes: track.likes_count,
          venue: track.show.venue_name,
          venue_url: track.show.venue&.url,
          location: track.show.venue&.location,
          songs: track.songs.map { |s| { title: s.title, slug: s.slug, url: s.url } },
          tags: track.tags.map { |t| { name: t.name, slug: t.slug } },
          gap: songs_track && {
            previous: songs_track.previous_performance_gap,
            next: songs_track.next_performance_gap,
            previous_slug: songs_track.previous_performance_slug,
            next_slug: songs_track.next_performance_slug
          }
        }
      end

      def apply_song_filter(tracks, song_slug)
        song = Song.find_by(slug: song_slug)
        return tracks.none unless song
        tracks.joins(:songs).where(songs: { id: song.id })
      end

      def apply_venue_filter(tracks, venue_slug)
        venue = Venue.find_by(slug: venue_slug)
        return tracks.none unless venue
        tracks.joins(:show).where(shows: { venue_id: venue.id })
      end

      def apply_tag_filter(tracks, tag_slug)
        tag = Tag.find_by(slug: tag_slug)
        return tracks.none unless tag
        tracks.joins(:tags).where(tags: { id: tag.id })
      end

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
          scope.joins(:show).order("shows.date #{direction}")
        end
      end

      def error_response(message)
        MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
      end
    end
  end
end
