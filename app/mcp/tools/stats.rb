module Mcp
  module Tools
    class Stats < MCP::Tool
      description "Statistical analysis of Phish performances. Supports gaps (bustouts), " \
                  "transitions, durations, venue patterns, set positions, predictions, " \
                  "streaks, era comparisons, covers, geographic patterns, and co-occurrence."

      input_schema(
        properties: {
          stat_type: {
            type: "string",
            enum: %w[gaps transitions durations venue_patterns set_positions predictions streaks era_comparison covers geographic co_occurrence],
            description: "Type of statistic to compute"
          },
          song_slug: { type: "string", description: "Song slug for song-specific analysis" },
          song_b_slug: { type: "string", description: "Second song slug for co-occurrence comparison" },
          venue_slug: { type: "string", description: "Venue slug for venue-specific analysis" },
          year: { type: "integer", description: "Filter to specific year" },
          year_range: { type: "array", items: { type: "integer" }, description: "Filter to year range [start, end]" },
          tour_slug: { type: "string", description: "Filter to specific tour" },
          state: { type: "string", description: "US state code for geographic analysis" },
          min_gap: { type: "integer", description: "Minimum show gap for bustout queries" },
          position: { type: "string", enum: %w[opener closer encore], description: "Set position filter" },
          direction: { type: "string", enum: %w[before after], description: "Transition direction" },
          cover_type: { type: "string", enum: %w[frequency ratio by_artist], description: "Cover analysis type" },
          geo_type: { type: "string", enum: %w[state_frequency never_played state_debuts], description: "Geographic analysis type" },
          compare_to: { type: "object", description: "Second era for comparison (year or year_range)" },
          limit: { type: "integer", description: "Limit results (default: 25)" }
        },
        required: ["stat_type"]
      )

      class << self
        def call(stat_type:, **options)
          result = PerformanceAnalysisService.call(
            analysis_type: stat_type,
            filters: options.compact,
            log_call: true
          )

          if result[:error]
            MCP::Tool::Response.new([{ type: "text", text: "Error: #{result[:error]}" }], is_error: true)
          else
            MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
          end
        end
      end
    end
  end
end
