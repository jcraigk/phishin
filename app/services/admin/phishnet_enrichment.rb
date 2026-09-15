class Admin::PhishnetEnrichment
  STEPS = [
    [ "Applying debut tags", ->(show) { DebutTagService.call(show) } ],
    [ "Syncing lore", ->(show) { LoreSyncService.call(date: show.date.to_s) } ],
    [ "Tagging teases from setlist notes", ->(show) { TeaseSyncService.new(date: show.date.to_s, apply: true).call } ],
    [ "Tagging teases from the Tease Chart", lambda { |show|
      TeaseChartSyncService.new(start_date: show.date.to_s, end_date: show.date.to_s, apply: true).call
    } ]
  ].freeze

  def self.call(show, &progress)
    new(show, &progress).call
  end

  def initialize(show, &progress)
    @show = show
    @progress = progress || ->(_message) { }
  end

  def call
    STEPS.filter_map do |message, step|
      @progress.call(message)
      step.call(@show)
      nil
    rescue StandardError => e
      "#{message} failed: #{e.message}"
    end
  end
end
