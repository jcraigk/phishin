module Tools
  class ListYears < MCP::Tool
    tool_name "list_years"

    description Descriptions::BASE[:list_years]

    annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

    input_schema(
      properties: {},
      required: []
    )

    class << self
      def call
        result = fetch_years_data
        MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      end

      def fetch_years_data
        Rails.cache.fetch(McpHelpers.cache_key_for_custom("years")) do
          {
            total_shows: Show.count,
            total_shows_with_audio: Show.where(audio_status: %w[complete partial]).count,
            years: years_data
          }
        end
      end

      private

      def years_data
        batch_stats = calculate_batch_statistics

        ERAS.flat_map do |era, periods|
          periods.map do |period|
            stats = batch_stats[period] || empty_stats
            {
              period:,
              url: McpHelpers.year_url(period),
              era:,
              shows_count: stats[:shows_count],
              shows_with_audio_count: stats[:shows_with_audio_count],
              shows_duration_ms: stats[:shows_duration],
              venues_count: stats[:venues_count]
            }
          end
        end
      end

      def calculate_batch_statistics
        all_periods = ERAS.values.flatten

        stats_query = all_periods.map do |period|
          condition = if period.include?("-")
            year1, year2 = period.split("-")
            date1 = Date.new(year1.to_i).beginning_of_year
            date2 = Date.new(year2.to_i).end_of_year
            "date BETWEEN '#{date1}' AND '#{date2}'"
          else
            "date_part('year', date) = #{period}"
          end

          <<~SQL
            SELECT
              '#{period}' as period,
              COUNT(*) as shows_count,
              COUNT(CASE WHEN audio_status IN ('complete', 'partial') THEN 1 END) as shows_with_audio_count,
              COUNT(DISTINCT venue_id) as venues_count,
              COALESCE(SUM(duration), 0) as shows_duration
            FROM shows
            WHERE (#{condition})
          SQL
        end

        union_query = stats_query.join(" UNION ALL ")
        results = ActiveRecord::Base.connection.execute(union_query)

        results.each_with_object({}) do |row, hash|
          hash[row["period"]] = {
            shows_count: row["shows_count"].to_i,
            shows_with_audio_count: row["shows_with_audio_count"].to_i,
            venues_count: row["venues_count"].to_i,
            shows_duration: row["shows_duration"].to_i
          }
        end
      end

      def empty_stats
        { shows_count: 0, shows_with_audio_count: 0, venues_count: 0, shows_duration: 0 }
      end
    end
  end
end
