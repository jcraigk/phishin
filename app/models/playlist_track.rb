class PlaylistTrack < ApplicationRecord
  belongs_to :playlist, counter_cache: :tracks_count
  belongs_to :track

  validates :position,
            numericality: { only_integer: true },
            uniqueness: { scope: :playlist_id }

  before_save :assign_duration

  private

  def assign_duration
    self.duration = excerpt_duration
  end

  def excerpt_duration
    start_second = starts_at_second.to_i
    end_second = ends_at_second.to_i
    if start_second <= 0 && end_second <= 0
      track.duration
    elsif start_second > 0 && end_second > 0
      (end_second - start_second) * 1000
    elsif start_second > 0
      (track.duration / 1000 - start_second) * 1000
    elsif end_second > 0
      end_second * 1000
    end
  end
end
