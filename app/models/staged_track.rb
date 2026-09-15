class StagedTrack < ApplicationRecord
  SETS = %w[S 1 2 3 4 E E2 E3].freeze
  MIN_LENGTH_S = 1.0
  DEFAULT_FADE_IN_S = 0.2
  DEFAULT_FADE_OUT_S = 6.0

  belongs_to :show

  validates :position, :title, :start_s, :end_s, presence: true
  validates :position, uniqueness: { scope: :show_id }
  validates :set, inclusion: { in: SETS }
  validates :fade_in_s, :fade_out_s, numericality: { greater_than_or_equal_to: 0 }
  validate :long_enough

  scope :ordered, -> { order(:position) }

  def songs
    by_id = Song.where(id: song_ids).index_by(&:id)
    song_ids.filter_map { by_id[it] }
  end

  def next_track
    show.staged_tracks.find_by(position: position + 1)
  end

  def previous_track
    show.staged_tracks.find_by(position: position - 1)
  end

  def self.rank(set)
    SETS.index(set) || -1
  end

  def self.normalize_sets!(show)
    floor = nil
    show.staged_tracks.order(:position).each do |row|
      if floor && rank(row.set) < rank(floor)
        row.update_columns(set: floor)
      else
        floor = row.set
      end
    end
  end

  def self.normalize_edge_fades!(show)
    rows = show.staged_tracks.order(:position).to_a
    rows.each_with_index do |row, i|
      prev_row = i.positive? ? rows[i - 1] : nil
      next_row = rows[i + 1]
      changes = {}
      if prev_row && prev_row.set == row.set
        changes[:fade_in_s] = 0 if row.fade_in_s.positive?
      elsif row.fade_in_s.zero?
        changes[:fade_in_s] = DEFAULT_FADE_IN_S
      end
      if next_row && next_row.set == row.set
        changes[:fade_out_s] = 0 if row.fade_out_s.positive?
      elsif row.fade_out_s.zero?
        changes[:fade_out_s] = DEFAULT_FADE_OUT_S
      end
      row.update_columns(changes) if changes.any?
    end
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
