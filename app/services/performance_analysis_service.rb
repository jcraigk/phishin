class PerformanceAnalysisService < ApplicationService
  option :analysis_type
  option :filters, default: -> { {} }
  option :log_call, default: -> { false }

  ANALYZERS = {
    gaps: PerformanceAnalysis::GapsAnalyzer,
    transitions: PerformanceAnalysis::TransitionsAnalyzer,
    set_positions: PerformanceAnalysis::SetPositionsAnalyzer,
    predictions: PerformanceAnalysis::PredictionsAnalyzer,
    streaks: PerformanceAnalysis::StreaksAnalyzer,
    geographic: PerformanceAnalysis::GeographicAnalyzer,
    co_occurrence: PerformanceAnalysis::CoOccurrenceAnalyzer,
    song_frequency: PerformanceAnalysis::SongFrequencyAnalyzer
  }.freeze

  def call
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = run_analysis

    log_mcp_call(result, start_time) if log_call

    result
  end

  private

  def run_analysis
    analyzer_class = ANALYZERS[analysis_type.to_sym]
    return { error: "Unknown analysis type: #{analysis_type}" } unless analyzer_class

    analyzer_class.new(filters:).call
  end

  def log_mcp_call(result, start_time)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    McpToolCall.log_call(
      tool_name: "stats",
      parameters: { analysis_type: analysis_type.to_s }.merge(filters),
      result:,
      duration_ms:
    )
  end
end
