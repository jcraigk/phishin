class PerformanceAnalysisService < ApplicationService
  option :analysis_type
  option :filters, default: -> { {} }

  ANALYZERS = {
    gaps: PerformanceAnalysis::GapsAnalyzer,
    transitions: PerformanceAnalysis::TransitionsAnalyzer,
    set_positions: PerformanceAnalysis::SetPositionsAnalyzer,
    geographic: PerformanceAnalysis::GeographicAnalyzer,
    co_occurrence: PerformanceAnalysis::CoOccurrenceAnalyzer,
    song_frequency: PerformanceAnalysis::SongFrequencyAnalyzer
  }.freeze

  def call
    analyzer_class = ANALYZERS[analysis_type.to_sym]
    return { error: "Unknown analysis type: #{analysis_type}" } unless analyzer_class

    analyzer_class.new(filters:).call
  end
end
