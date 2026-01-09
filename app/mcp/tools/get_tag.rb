module Tools
  class GetTag < MCP::Tool
    tool_name "get_tag"

    description Descriptions::BASE[:get_tag]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(
      properties: {
        slug: { type: "string", description: "Tag slug (e.g., 'jamcharts', 'costume', 'guest')" },
        type: {
          type: "string",
          enum: %w[show track],
          description: "Entity type to return: 'show' for tagged shows, 'track' for tagged tracks"
        },
        sort_by: {
          type: "string",
          enum: %w[date likes duration random],
          description: "Sort by date (default), likes, duration (tracks only), or random"
        },
        sort_order: {
          type: "string",
          enum: %w[asc desc],
          description: "Sort order: asc or desc (default: desc)"
        },
        limit: { type: "integer", description: "Max items to return (default: 25)" }
      },
      required: %w[slug type]
    )

    class << self
      def call(slug:, type:, sort_by: "date", sort_order: "desc", limit: 25)
        tag = Tag.find_by(slug:)
        return error_response("Tag not found") unless tag

        result = case type
        when "show"
          fetch_shows_data(tag, sort_by, sort_order, limit)
        when "track"
          fetch_tracks_data(tag, sort_by, sort_order, limit)
        end

        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      private

      def fetch_shows_data(tag, sort_by, sort_order, limit)
        cache_key = McpHelpers.cache_key_for_collection(
          "tags/#{tag.slug}/shows",
          { sort_by:, sort_order:, limit: }
        )

        Rails.cache.fetch(cache_key) do
          shows = Show.joins(:show_tags)
                      .where(show_tags: { tag_id: tag.id })
                      .includes(:venue, :tour)

          shows = apply_show_sort(shows, sort_by, sort_order)
          shows = shows.limit(limit)

          show_list = shows.map do |show|
            {
              date: show.date.iso8601,
              url: show.url,
              venue: show.venue_name,
              venue_url: show.venue&.url,
              location: show.venue&.location,
              tour: show.tour&.name,
              duration_ms: show.duration,
              duration_display: McpHelpers.format_duration(show.duration),
              likes: show.likes_count
            }
          end

          build_result(tag, "shows", show_list)
        end
      end

      def fetch_tracks_data(tag, sort_by, sort_order, limit)
        cache_key = McpHelpers.cache_key_for_collection(
          "tags/#{tag.slug}/tracks",
          { sort_by:, sort_order:, limit: }
        )

        Rails.cache.fetch(cache_key) do
          tracks = Track.joins(:track_tags)
                        .where(track_tags: { tag_id: tag.id })
                        .includes(show: :venue)

          tracks = apply_track_sort(tracks, sort_by, sort_order)
          tracks = tracks.limit(limit)

          track_list = tracks.map do |track|
            {
              title: track.title,
              slug: track.slug,
              url: track.url,
              date: track.show.date.iso8601,
              show_url: track.show.url,
              venue: track.show.venue_name,
              location: track.show.venue&.location,
              duration_ms: track.duration,
              duration_display: McpHelpers.format_duration(track.duration),
              likes: track.likes_count
            }
          end

          build_result(tag, "tracks", track_list)
        end
      end

      def build_result(tag, items_key, items)
        {
          name: tag.name,
          slug: tag.slug,
          group: tag.group,
          description: tag.description,
          shows_count: tag.shows_count,
          tracks_count: tag.tracks_count,
          items_key => items
        }
      end

      def apply_show_sort(scope, sort_by, sort_order)
        direction = sort_order == "asc" ? :asc : :desc

        case sort_by
        when "likes"
          scope.order(likes_count: direction)
        when "random"
          scope.order(Arel.sql("RANDOM()"))
        else
          scope.order(date: direction)
        end
      end

      def apply_track_sort(scope, sort_by, sort_order)
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
