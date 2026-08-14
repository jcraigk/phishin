class AdminJob < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  belongs_to :show, optional: true
  belongs_to :track, optional: true

  validates :kind, presence: true
  validates :status, inclusion: { in: STATUSES }

  def run!
    update!(status: "running")
    yield self
    update!(status: "done", progress: 100)
  rescue StandardError => e
    update!(status: "failed", message: e.message)
    raise
  end
end
