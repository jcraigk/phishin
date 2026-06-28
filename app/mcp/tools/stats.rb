module Tools
  class Stats < MCP::Tool
    tool_name "stats"

    description Descriptions::BASE[:stats]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(
      properties: {
        stat_type: {
          type: "string",
          enum: %w[gaps transitions set_positions geographic co_occurrence song_frequency],
          description: "Which statistic to compute. This selects the analysis and determines which other " \
                       "parameters apply; each parameter below notes the stat_type(s) it affects."
        },
        song_slug: {
          type: "string",
          description: "Song slug. Required when stat_type is 'co_occurrence' (the primary song). " \
                       "Optional for 'transitions' and 'set_positions' to scope results to one song. " \
                       "Ignored by other stat_types."
        },
        song_b_slug: {
          type: "string",
          description: "Second song slug. Used only by 'co_occurrence': when provided, compares this song " \
                       "against song_slug; when omitted, returns song_slug's most common pairings."
        },
        venue_slug: {
          type: "string",
          description: "Venue slug filter. Applies only to 'song_frequency'; ignored by other stat_types."
        },
        year: {
          type: "integer",
          description: "Filter to a single year. Applies only to 'song_frequency'. " \
                       "Mutually exclusive with year_range; if both are given, year takes precedence."
        },
        year_range: {
          type: "array",
          items: { type: "integer" },
          minItems: 2,
          maxItems: 2,
          description: "Inclusive year range as exactly two integers in ascending order: [start_year, end_year]. " \
                       "Applies only to 'song_frequency'. Ignored when year is provided."
        },
        tour_slug: {
          type: "string",
          description: "Tour slug filter. Applies only to 'song_frequency'; ignored by other stat_types."
        },
        state: {
          type: "string",
          description: "Two-letter US state code. Required when stat_type is 'geographic' and geo_type is " \
                       "'never_played'. Also acts as a filter for 'song_frequency'. Ignored by other stat_types."
        },
        min_gap: {
          type: "integer",
          description: "Minimum show gap for bustout queries. Used only by 'gaps'."
        },
        min_plays: {
          type: "integer",
          description: "Minimum times played to include (default: 2). Used only by 'gaps'."
        },
        position: {
          type: "string",
          enum: %w[opener closer encore],
          description: "Set position filter. Used only by 'set_positions'."
        },
        set: {
          type: "string",
          enum: %w[1 2 3 4],
          description: "Set number for opener/closer analysis (default: 1 for openers, 2 for closers). " \
                       "Used only by 'set_positions'."
        },
        direction: {
          type: "string",
          enum: %w[before after],
          description: "Transition direction (default: after). Used only by 'transitions'."
        },
        geo_type: {
          type: "string",
          enum: %w[state_frequency never_played state_debuts],
          description: "Geographic analysis type (default: state_frequency). Used only by 'geographic'. " \
                       "'never_played' additionally requires state."
        },
        limit: {
          type: "integer",
          description: "Max results to return (default: 25). Set this to match how many results you intend to display."
        }
      },
      required: [ "stat_type" ],
      allOf: [
        {
          # co_occurrence cannot run without a primary song
          if: { properties: { stat_type: { const: "co_occurrence" } }, required: [ "stat_type" ] },
          then: { required: [ "song_slug" ] }
        },
        {
          # the 'never_played' geographic report is scoped to a single state
          if: {
            properties: { stat_type: { const: "geographic" }, geo_type: { const: "never_played" } },
            required: [ "stat_type", "geo_type" ]
          },
          then: { required: [ "state" ] }
        }
      ]
    )

    output_schema OutputSchemas::STATS

    class << self
      def call(stat_type:, **options)
        result = fetch_stats(stat_type, options.compact)

        if result[:error]
          MCP::Tool::Response.new([ { type: "text", text: "Error: #{result[:error]}" } ], error: true)
        else
          MCP::Tool::Response.new([ { type: "text", text: result.to_json } ], structured_content: result)
        end
      end

      def fetch_stats(stat_type, filters)
        cache_key = McpHelpers.cache_key_for_collection("stats/#{stat_type}", filters)

        Rails.cache.fetch(cache_key) do
          PerformanceAnalysisService.call(
            analysis_type: stat_type,
            filters:,
            log_call: true
          )
        end
      end
    end
  end
end
