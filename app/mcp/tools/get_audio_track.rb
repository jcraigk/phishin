module Tools
  class GetAudioTrack < MCP::Tool
    tool_name "get_audio_track"

    description Descriptions::BASE[:get_audio_track]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Track slug: 'YYYY-MM-DD/track-slug' (e.g., '1997-11-22/tweezer'). Omit for random." },
        random: { type: "boolean", description: "Set to true for a random audio track" }
      },
      required: []
    )

    def self.openai_meta
      {
        "openai/outputTemplate" => Server.widget_uri("get_audio_track"),
        "openai/widgetAccessible" => true,
        "openai/widgetDescription" => "Interactive audio player with album art for playing a song performance",
        "openai/outputHint" => "The widget above displays the track with playback controls. " \
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
          .where(audio_status: %w[complete partial])
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
            :tour,
            :tracks,
            cover_art_attachment: { blob: { variant_records: { image_attachment: :blob } } },
            venue: :map_snapshot_attachment
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
        show = track.show
        playable_tracks = ChronologicalTrackNavigator.playable_tracks_for_show(show)
        current_index = playable_tracks.find_index { |t| t.id == track.id } || 0

        prev_show = ChronologicalTrackNavigator.adjacent_show(show, direction: :prev)
        next_show = ChronologicalTrackNavigator.adjacent_show(show, direction: :next)

        first_track = ChronologicalTrackNavigator.first_track
        last_track = ChronologicalTrackNavigator.last_track

        {
          base_url: App.base_url,
          current_track_index: current_index,
          is_library_start: track.id == first_track&.id,
          is_library_end: track.id == last_track&.id,
          show: build_show_data(show, playable_tracks),
          prev_show: prev_show && build_adjacent_show_data(prev_show, :last),
          next_show: next_show && build_adjacent_show_data(next_show, :first)
        }
      end

      def build_show_data(show, playable_tracks)
        set_positions = compute_set_positions(playable_tracks)
        {
          date: show.date.iso8601,
          show_url: show.url,
          venue: show.venue_name,
          venue_slug: show.venue&.slug,
          location: show.venue&.location,
          map_snapshot_url: show.venue&.map_snapshot_url,
          cover_art_url: show.cover_art_urls[:medium],
          duration_ms: show.duration,
          tracks: playable_tracks.map { |t| build_track_item(t, set_positions[t.id]) }
        }
      end

      def compute_set_positions(tracks)
        positions = {}
        tracks.group_by(&:set).each_value do |set_tracks|
          set_tracks.sort_by(&:position).each_with_index do |track, idx|
            positions[track.id] = idx + 1
          end
        end
        positions
      end

      def build_track_item(track, set_position = nil)
        {
          id: track.id,
          title: track.title,
          slug: track.slug,
          url: track.url,
          set: track.set_name,
          position: set_position || track.position,
          duration_ms: track.duration,
          mp3_url: track.mp3_url,
          waveform_image_url: track.waveform_image_url,
          tags: track.track_tags.map { |tt| { name: tt.tag.name, slug: tt.tag.slug, description: tt.tag.description, notes: tt.notes } }
        }
      end

      def build_adjacent_show_data(show, track_position)
        playable = ChronologicalTrackNavigator.playable_tracks_for_show(show)
        target_track = track_position == :first ? playable.first : playable.last

        {
          date: show.date.iso8601,
          venue: show.venue_name,
          track_count: playable.count,
          target_track_slug: "#{show.date}/#{target_track&.slug}"
        }
      end

      def error_response(message)
        hint = "Try using 'search' to find tracks, or 'get_show' with a valid date to see available tracks."
        MCP::Tool::Response.new(
          [ { type: "text", text: "#{message}. #{hint}" } ],
          error: true
        )
      end
    end
  end
end
