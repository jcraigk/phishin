class McpToolCall < ApplicationRecord
  validates :tool_name, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_tool, ->(name) { where(tool_name: name) }
  scope :successful, -> { where(error_message: nil) }
  scope :failed, -> { where.not(error_message: nil) }
  scope :since, ->(time) { where("created_at >= ?", time) }

  def self.log_call(tool_name:, parameters: {}, result: nil, duration_ms: nil)
    create!(
      tool_name: tool_name,
      parameters: parameters,
      result_summary: build_result_summary(result),
      result_count: extract_result_count(result),
      duration_ms: duration_ms,
      error_message: result.is_a?(Hash) ? result[:error] : nil
    )
  rescue StandardError => e
    Rails.logger.error("Failed to log MCP tool call: #{e.message}")
    nil
  end

  def self.build_result_summary(result)
    return {} unless result.is_a?(Hash)

    summary = {}
    summary[:error] = result[:error] if result[:error]
    summary[:keys] = result.keys.map(&:to_s)
    summary
  end

  def self.extract_result_count(result)
    return nil unless result.is_a?(Hash)

    result.each_value do |value|
      return value.size if value.is_a?(Array)
    end

    nil
  end

  def successful?
    error_message.blank?
  end

  def failed?
    error_message.present?
  end
end
