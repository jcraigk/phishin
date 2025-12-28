module Tools
  class GetShow < MCP::Tool
    tool_name "get_show"

    description "Get full details for a single Phish show and display an interactive widget with audio player. " \
                "WHEN TO USE: For specific dates ('Halloween 1995', '12/31/99'), " \
                "or as a follow-up to list_shows/search when the user wants details on a single show. " \
                "Returns setlist with all tracks, venue, tags, and gaps. " \
                "DISPLAY: In markdown, link the date to show url and songs to track url. " \
                "Format dates readably (e.g., 'Jul 4, 2023'). " \
                "WIDGET: If a widget is displayed, provide only a brief 1-2 sentence summary. " \
                "Do NOT list tracks - the widget displays the full setlist with playback controls."

    meta({
      "openai/outputTemplate" => Server.widget_uri("get_show"),
      "openai/widgetAccessible" => true,
      "openai/widgetDescription" => "Interactive show card with album art and full setlist",
      "openai/outputHint" => "The widget above displays the complete setlist. DO NOT list tracks or songs. " \
                             "Instead, provide a brief 1-2 sentence summary of notable moments, historical context, " \
                             "or why this show is significant. Keep your response very short."
    })

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        date: { type: "string", description: "Show date (YYYY-MM-DD)" }
      },
      required: [ "date" ]
    )

    class << self
      def call(date:)
        show = Show.includes(
          :venue, :tour,
          tracks: [ :songs, { track_tags: :tag, songs_tracks: {} } ],
          show_tags: :tag
        ).find_by(date:)

        return error_response("Show not found for date: #{date}") unless show

        result = build_show_data(show)

        MCP::Tool::Response.new(
          [ { type: "text", text: result.to_json } ],
          structured_content: build_widget_data(show)
        )
      end

      private

      def build_show_data(show)
        {
          date: show.date.iso8601,
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
          venue: show.venue_name,
          venue_slug: show.venue&.slug,
          location: show.venue&.location,
          duration_ms: show.duration,
          taper_notes: show.taper_notes,
          cover_art_url: show.cover_art_urls[:medium],
          cover_art_url_large: show.cover_art_urls[:large],
          album_cover_url: show.album_cover_url,
          show_url: show.url,
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
        MCP::Tool::Response.new(
          [ { type: "text", text: "Error: #{message}" } ],
          structured_content: { error: true, message: }
        )
      end
    end
  end
end
