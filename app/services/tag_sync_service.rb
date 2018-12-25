# frozen_string_literal: true
class TagSyncService
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def call
    ensure_tags_found
    sync_tags
  end

  private

  def method_name

  end
end
