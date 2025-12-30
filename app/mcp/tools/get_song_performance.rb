module Tools
  class GetSongPerformance < MCP::Tool
    tool_name "get_song_performance"

    description Descriptions::BASE[:get_song_performance]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Performance slug: 'YYYY-MM-DD/track-slug' (e.g., '1997-11-22/tweezer'). Omit for random." },
        random: { type: "boolean", description: "Set to true for a random song performance" }
      },
      required: []
    )

    def self.openai_meta
      {
        "openai/outputTemplate" => Server.widget_uri("get_song_performance"),
        "openai/widgetAccessible" => true,
        "openai/widgetDescription" => "Interactive audio player with album art for a song performance",
        "openai/outputHint" => "The widget above displays the performance with playback controls. " \
                              "Provide a brief 1-2 sentence summary about this performance, " \
                              "such as notable qualities, length, or historical context."
      }
    end

    class << self
      def call(slug: nil, random: false)
        track = if random || slug.nil?
          fetch_random_track
        else
          fetch_track(slug)
        end
        return error_response("Track not found") unless track

        result = build_track_data(track)
        structured = mcp_client == :openai ? build_widget_data(track) : nil

        MCP::Tool::Response.new(
          [ { type: "text", text: result.to_json } ],
          structured_content: structured
        )
      end

      def mcp_client
        :default
      end

      def fetch_track(slug)
        parts = slug.to_s.split("/", 2)
        return nil unless parts.length == 2

        date, track_slug = parts

        Rails.cache.fetch(McpHelpers.cache_key_for_resource("tracks", slug)) do
          track_includes.joins(:show).find_by(shows: { date: }, slug: track_slug)
        end
      end

      def fetch_random_track
        track_includes
          .where.not(set: %w[S P])
          .where(exclude_from_stats: false)
          .order(Arel.sql("RANDOM()"))
          .first
      end

      def track_includes
        Track.includes(
          :songs, :tags,
          :mp3_audio_attachment, :png_waveform_attachment,
          songs_tracks: {},
          track_tags: :tag,
          show: [
            :venue, :tour,
            cover_art_attachment: { blob: { variant_records: { image_attachment: :blob } } }
          ]
        )
      end

      private

      def build_track_data(track)
        songs_track = track.songs_tracks.first
        song = track.songs.first

        {
          title: track.title,
          slug: track.slug,
          url: track.url,
          date: track.show.date.iso8601,
          show_url: track.show.url,
          set: track.set,
          set_name: track.set_name,
          position: track.position,
          duration_ms: track.duration,
          duration_display: McpHelpers.format_duration(track.duration),
          likes: track.likes_count,
          venue: {
            name: track.show.venue_name,
            slug: track.show.venue&.slug,
            url: track.show.venue&.url,
            city: track.show.venue&.city,
            state: track.show.venue&.state,
            country: track.show.venue&.country
          },
          location: track.show.venue&.location,
          tour: track.show.tour&.name,
          tour_slug: track.show.tour&.slug,
          song: song && {
            title: song.title,
            slug: song.slug,
            url: song.url
          },
          tags: track.track_tags.map { |tt| { name: tt.tag.name, slug: tt.tag.slug, notes: tt.notes } },
          gap: songs_track && {
            previous: songs_track.previous_performance_gap,
            next: songs_track.next_performance_gap,
            previous_slug: songs_track.previous_performance_slug,
            next_slug: songs_track.next_performance_slug
          }
        }
      end

      def build_widget_data(track)
        songs_track = track.songs_tracks.first
        song = track.songs.first

        {
          title: track.title,
          slug: track.slug,
          url: track.url,
          date: track.show.date.iso8601,
          show_url: track.show.url,
          set: track.set_name,
          duration: McpHelpers.format_duration(track.duration),
          duration_ms: track.duration,
          mp3_url: track.mp3_url,
          waveform_image_url: track.waveform_image_url,
          venue: track.show.venue_name,
          venue_slug: track.show.venue&.slug,
          location: track.show.venue&.location,
          cover_art_url: track.show.cover_art_urls[:medium],
          song: song && {
            title: song.title,
            slug: song.slug,
            url: song.url
          },
          tags: track.track_tags.map { |tt| { name: tt.tag.name, slug: tt.tag.slug, description: tt.tag.description, notes: tt.notes } },
          gap: songs_track && {
            previous: songs_track.previous_performance_gap,
            next: songs_track.next_performance_gap,
            previous_slug: songs_track.previous_performance_slug,
            next_slug: songs_track.next_performance_slug
          }
        }
      end

      def error_response(message)
        MCP::Tool::Response.new(
          [ { type: "text", text: "Error: #{message}" } ],
          structured_content: { error: true, message: }
        )
      end
    end
  end
end
