class AdminJob < ApplicationRecord
  STATUSES = %w[queued running done failed cancelled].freeze
  ACTIVE_STATUSES = %w[queued running].freeze
  CANCELLABLE_KINDS = %w[ingest].freeze

  class Cancelled < StandardError; end

  belongs_to :show, optional: true
  belongs_to :track, optional: true

  validates :kind, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  def run!
    update!(status: "running")
    yield self
    update!(status: "done", progress: 100)
  rescue Cancelled
    update!(status: "cancelled", message: "Cancelled")
    raise
  rescue StandardError => e
    update!(status: "failed", message: e.message)
    raise
  end

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def progress!(progress, message)
    check_cancel!
    update!(progress:, message:)
  end

  def cancellable?
    active? && kind.in?(CANCELLABLE_KINDS) && cancel_requested_at.nil?
  end

  def request_cancel!
    update!(cancel_requested_at: Time.current)
  end

  def check_cancel!
    raise Cancelled, "Cancelled" if AdminJob.where(id:).where.not(cancel_requested_at: nil).exists?
  end
end
