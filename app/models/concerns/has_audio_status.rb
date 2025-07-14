module HasAudioStatus
  extend ActiveSupport::Concern

  AUDIO_STATUSES = %w[complete partial missing].freeze

  included do
    validates :audio_status, inclusion: { in: AUDIO_STATUSES }

    scope :with_audio, -> { where(audio_status: %w[complete partial]) }
    scope :missing_audio, -> { where(audio_status: "missing") }
  end

  def has_audio?
    audio_status != "missing"
  end

  def missing_audio?
    audio_status == "missing"
  end

  def complete_audio?
    audio_status == "complete"
  end

  def partial_audio?
    audio_status == "partial"
  end

  def complete_or_partial_audio?
    %w[complete partial].include?(audio_status)
  end
end
