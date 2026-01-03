module Tools
  class GetAdjacentShow < MCP::Tool
    tool_name "get_adjacent_show"

    description "Fetch the next or previous show's data for audio playback navigation. " \
                "Returns full show data including all playable tracks for gapless playback. " \
                "Used by the audio player widget to navigate between shows."

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        current_show_date: {
          type: "string",
          description: "Current show date (YYYY-MM-DD)"
        },
        direction: {
          type: "string",
          enum: %w[next prev],
          description: "Navigation direction: 'next' or 'prev'"
        }
      },
      required: %w[current_show_date direction]
    )

    def self.openai_meta
      {
        "openai/widgetAccessible" => true
      }
    end

    class << self
      def call(current_show_date:, direction:)
        current_show = Show.find_by(date: current_show_date)
        return error_response("Current show not found") unless current_show

        adjacent_show = ChronologicalTrackNavigator.adjacent_show(current_show, direction: direction.to_sym)

        adjacent_show ||= if direction.to_sym == :next
          Show.with_audio.order(:date).first
        else
          Show.with_audio.order(date: :desc).first
        end

        return error_response("No adjacent show found") unless adjacent_show

        adjacent_show = show_includes.find(adjacent_show.id)

        structured = build_show_data(adjacent_show, direction.to_sym)

        MCP::Tool::Response.new(
          [ { type: "text", text: { date: adjacent_show.date.iso8601, venue: adjacent_show.venue_name }.to_json } ],
          structured_content: structured
        )
      end

      def mcp_client
        :default
      end

      def show_includes
        Show.includes(
          :tour,
          venue: :map_snapshot_attachment,
          tracks: [ :songs, :mp3_audio_attachment, :png_waveform_attachment, { track_tags: :tag } ],
          cover_art_attachment: { blob: { variant_records: { image_attachment: :blob } } }
        )
      end

      private

      def build_show_data(show, direction)
        playable_tracks = ChronologicalTrackNavigator.playable_tracks_for_show(show)
        start_index = direction == :next ? 0 : playable_tracks.count - 1

        prev_show = ChronologicalTrackNavigator.adjacent_show(show, direction: :prev)
        next_show = ChronologicalTrackNavigator.adjacent_show(show, direction: :next)

        first_track = ChronologicalTrackNavigator.first_track
        last_track = ChronologicalTrackNavigator.last_track
        current_track = direction == :next ? playable_tracks.first : playable_tracks.last

        {
          current_track_index: start_index,
          is_library_start: current_track&.id == first_track&.id,
          is_library_end: current_track&.id == last_track&.id,
          show: {
            date: show.date.iso8601,
            show_url: show.url,
            venue: show.venue_name,
            venue_slug: show.venue&.slug,
            location: show.venue&.location,
            map_snapshot_url: show.venue&.map_snapshot_url,
            cover_art_url: show.cover_art_urls[:medium],
            duration_ms: show.duration,
            tracks: playable_tracks.map { |t| build_track_item(t) }
          },
          prev_show: prev_show && build_adjacent_show_preview(prev_show, :last),
          next_show: next_show && build_adjacent_show_preview(next_show, :first)
        }
      end

      def build_track_item(track)
        {
          id: track.id,
          title: track.title,
          slug: track.slug,
          url: track.url,
          set: track.set_name,
          position: track.position,
          duration_ms: track.duration,
          mp3_url: track.mp3_url,
          waveform_image_url: track.waveform_image_url,
          tags: track.track_tags.map { |tt| { name: tt.tag.name, slug: tt.tag.slug, description: tt.tag.description, notes: tt.notes } }
        }
      end

      def build_adjacent_show_preview(show, track_position)
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
        MCP::Tool::Response.new(
          [ { type: "text", text: "Error: #{message}" } ],
          structured_content: { error: true, message: }
        )
      end
    end
  end
end
