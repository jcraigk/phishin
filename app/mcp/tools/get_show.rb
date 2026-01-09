module Tools
  class GetShow < MCP::Tool
    tool_name "get_show"

    description Descriptions::BASE[:get_show]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: true)

    input_schema(
      properties: {
        date: { type: "string", description: "Show date (YYYY-MM-DD). Omit for random show." },
        random: { type: "boolean", description: "Set to true for a random show (ignores date)" }
      },
      required: []
    )

    def self.openai_meta
      {
        "openai/outputTemplate" => Server.widget_uri("get_show"),
        "openai/widgetAccessible" => true,
        "openai/widgetDescription" => "Interactive show card with album art and full setlist",
        "openai/outputHint" => "The widget above displays the complete setlist. DO NOT list tracks or songs. " \
                               "Instead, provide a brief 1-2 sentence summary of notable moments, historical context, " \
                               "or why this show is significant. Keep your response very short."
      }
    end

    class << self
      def call(date: nil, random: false)
        show = if random || date.nil?
          fetch_random_show
        else
          fetch_show(date)
        end
        return error_response("Show not found") unless show

        result = build_show_data(show)
        structured = mcp_client == :openai ? build_widget_data(show) : nil

        MCP::Tool::Response.new(
          [ { type: "text", text: result.to_json } ],
          structured_content: structured
        )
      end

      def mcp_client
        :default
      end

      def fetch_show(date)
        Rails.cache.fetch(McpHelpers.cache_key_for_resource("shows", date)) do
          show_includes.find_by(date:)
        end
      end

      def fetch_random_show
        show_includes.with_audio.order(Arel.sql("RANDOM()")).first
      end

      def show_includes
        Show.includes(
          :tour,
          tracks: [ :songs, :mp3_audio_attachment, :png_waveform_attachment, { track_tags: :tag, songs_tracks: {} } ],
          show_tags: :tag,
          cover_art_attachment: { blob: { variant_records: { image_attachment: :blob } } },
          album_cover_attachment: :blob
        )
      end

      private

      def build_show_data(show)
        {
          date: show.date.iso8601,
          previous_show_date: show.previous_show_date&.iso8601,
          next_show_date: show.next_show_date&.iso8601,
          url: show.url,
          venue: {
            name: show.venue_name,
            slug: show.venue.slug,
            url: show.venue.url,
            city: show.venue.city,
            state: show.venue.state,
            country: show.venue.country
          },
          location: show.venue&.location,
          tour: show.tour&.name,
          tour_slug: show.tour&.slug,
          duration_ms: show.duration,
          duration_display: McpHelpers.format_duration(show.duration),
          likes: show.likes_count,
          audio_status: show.audio_status,
          taper_notes: show.taper_notes,
          tags: show.show_tags.map { |st| { name: st.tag.name, slug: st.tag.slug, notes: st.notes } },
          tracks: build_tracks_data(show)
        }
      end

      def build_tracks_data(show)
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

      def build_widget_data(show)
        {
          date: show.date.iso8601,
          previous_show_date: show.previous_show_date&.iso8601,
          next_show_date: show.next_show_date&.iso8601,
          venue: show.venue_name,
          venue_slug: show.venue&.slug,
          location: show.venue&.location,
          duration_ms: show.duration,
          taper_notes: show.taper_notes,
          cover_art_url: show.cover_art_urls[:medium],
          cover_art_url_large: show.cover_art_urls[:large],
          album_cover_url: show.album_cover_url,
          show_url: show.url,
          tags: show.show_tags.map { |st| { name: st.tag.name, slug: st.tag.slug, description: st.tag.description, notes: st.notes } },
          tracks: show.tracks.sort_by(&:position).map do |track|
            songs_track = track.songs_tracks.first
            song = track.songs.first
            {
              title: track.title,
              set: track.set_name,
              duration: McpHelpers.format_duration(track.duration),
              duration_ms: track.duration,
              url: track.url,
              mp3_url: track.mp3_url,
              waveform_image_url: track.waveform_image_url,
              song: song && { title: song.title, slug: song.slug },
              tags: track.track_tags.map { |tt| { name: tt.tag.name, slug: tt.tag.slug, description: tt.tag.description, notes: tt.notes } },
              gap: songs_track && {
                previous: songs_track.previous_performance_gap,
                next: songs_track.next_performance_gap,
                previous_slug: songs_track.previous_performance_slug,
                next_slug: songs_track.next_performance_slug
              }
            }
          end
        }
      end

      def error_response(message)
        hint = "Try using 'search' to find shows by keyword, or 'list_shows' with year/date filters to browse available shows."
        MCP::Tool::Response.new(
          [ { type: "text", text: "#{message}. #{hint}" } ],
          error: true
        )
      end
    end
  end
end
