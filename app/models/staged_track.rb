class StagedTrack < ApplicationRecord
  SETS = %w[S 1 2 3 4 E E2 E3].freeze
  MIN_LENGTH_S = 1.0

  belongs_to :show
  belongs_to :song, optional: true

  validates :position, :title, :start_s, :end_s, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :set, inclusion: { in: SETS }
  validates :fade_in_s, :fade_out_s, numericality: { greater_than_or_equal_to: 0 }
  validate :long_enough

  scope :ordered, -> { order(:position) }

  def length_s
    end_s - start_s
  end

  def next_track
    show.staged_tracks.find_by(position: position + 1)
  end

  def previous_track
    show.staged_tracks.find_by(position: position - 1)
  end

  def self.renumber!(show)
    transaction do
      rows = show.staged_tracks.order(:start_s, :id).to_a
      rows.each_with_index { |row, i| row.update_columns(position: -(i + 1)) }
      rows.each_with_index { |row, i| row.update_columns(position: i + 1) }
    end
  end

  private

  def long_enough
    return if start_s.nil? || end_s.nil?
    return if end_s - start_s >= MIN_LENGTH_S
    errors.add(:end_s, "must be at least #{MIN_LENGTH_S}s after the start")
  end
end
