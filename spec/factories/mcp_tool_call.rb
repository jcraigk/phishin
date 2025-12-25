FactoryBot.define do
  factory :mcp_tool_call do
    tool_name { "stats" }
    parameters { { stat_type: "gaps", min_gap: 50 } }
    result_summary { { keys: %w[songs latest_show_date] } }
    result_count { 10 }
    duration_ms { 150 }

    trait :failed do
      error_message { "Song not found" }
      result_summary { { error: "Song not found", keys: ["error"] } }
      result_count { nil }
    end

    trait :transitions do
      parameters { { stat_type: "transitions", song_slug: "tweezer", direction: "after" } }
    end

    trait :durations do
      parameters { { stat_type: "durations", song_slug: "tweezer", limit: 10 } }
    end

    trait :search do
      tool_name { "search" }
      parameters { { query: "tweezer", scope: "songs" } }
    end
  end
end
