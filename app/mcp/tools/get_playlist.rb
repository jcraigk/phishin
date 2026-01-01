module Tools
  class GetPlaylist < MCP::Tool
    tool_name "get_playlist"

    description Descriptions::BASE[:get_playlist]

    annotations(read_only_hint: true, destructive_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Playlist slug (omit for random playlist)" }
      },
      required: []
    )

    def self.openai_meta
      {
        "openai/outputTemplate" => Server.widget_uri("get_playlist"),
        "openai/widgetAccessible" => true,
        "openai/widgetDescription" => "Interactive playlist card with track listing",
        "openai/outputHint" => "The widget above displays the playlist with all tracks. DO NOT list tracks. " \
                               "Instead, provide a brief 1-2 sentence description of the playlist theme or highlights. " \
                               "Keep your response very short."
      }
    end

    class << self
      def call(slug: nil)
        playlist = if slug
          Playlist.published.includes(:user).find_by(slug:)
        else
          Playlist.published.includes(:user).order(Arel.sql("RANDOM()")).first
        end
        return error_response("Playlist not found") unless playlist

        result = fetch_playlist_data(playlist, cache: slug.present?)
        structured = mcp_client == :openai ? build_widget_data(playlist) : nil

        MCP::Tool::Response.new(
          [ { type: "text", text: result.to_json } ],
          structured_content: structured
        )
      end

      def mcp_client
        :default
      end

      def fetch_playlist_data(playlist, cache: true)
        if cache
          Rails.cache.fetch(McpHelpers.cache_key_for_resource("playlists", playlist.slug)) do
            build_playlist_data(playlist)
          end
        else
          build_playlist_data(playlist)
        end
      end

      def build_playlist_data(playlist)
        tracks = playlist.playlist_tracks.order(:position).includes(track: { show: :venue })

        track_list = tracks.map do |pt|
          track = pt.track
          {
            position: pt.position,
            title: track.title,
            slug: track.slug,
            song_slug: track.songs.first&.slug,
            date: track.show.date.iso8601,
            venue: track.show.venue_name,
            location: track.show.venue&.location,
            duration_ms: track.duration,
            duration_display: McpHelpers.format_duration(track.duration),
            set: track.set,
            url: track.url
          }
        end

        {
          name: playlist.name,
          slug: playlist.slug,
          url: playlist.url,
          description: playlist.description,
          duration_ms: playlist.duration,
          duration_display: McpHelpers.format_duration(playlist.duration),
          track_count: tracks.size,
          tracks: track_list
        }
      end

      def build_widget_data(playlist)
        tracks = playlist.playlist_tracks.order(:position).includes(
          track: [ :mp3_audio_attachment, :png_waveform_attachment, { track_tags: :tag, show: [ :venue, cover_art_attachment: { blob: { variant_records: { image_attachment: :blob } } } ] } ]
        )

        first_track = tracks.first&.track
        cover_art_url = first_track&.show&.cover_art_urls&.dig(:medium)

        {
          name: playlist.name,
          slug: playlist.slug,
          url: playlist.url,
          description: playlist.description,
          duration_ms: playlist.duration,
          duration_display: McpHelpers.format_duration(playlist.duration),
          track_count: tracks.size,
          username: playlist.user&.username,
          cover_art_url:,
          tracks: tracks.map do |pt|
            track = pt.track
            {
              position: pt.position,
              title: track.title,
              date: track.show.date.iso8601,
              show_url: track.show.url,
              venue: track.show.venue_name,
              venue_url: track.show.venue&.url,
              location: track.show.venue&.location,
              duration_ms: track.duration,
              duration_display: McpHelpers.format_duration(track.duration),
              url: track.url,
              mp3_url: track.mp3_url,
              waveform_image_url: track.waveform_image_url,
              tags: track.track_tags.map { |tt| { name: tt.tag.name, slug: tt.tag.slug } }
            }
          end
        }
      end

      private

      def error_response(message)
        MCP::Tool::Response.new(
          [ { type: "text", text: "Error: #{message}" } ],
          structured_content: { error: true, message: }
        )
      end
    end
  end
end
