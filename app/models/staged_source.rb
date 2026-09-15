class StagedSource < ApplicationRecord
  FORMATS = %w[flac shn wav aiff mp3].freeze

  belongs_to :show

  validates :position, :filename, :offset_s, :duration_s, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :format, inclusion: { in: FORMATS }

  def end_s
    offset_s + duration_s
  end

  def mp3?
    format == "mp3"
  end
end
