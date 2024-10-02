class PlaylistTrack < ApplicationRecord
  belongs_to :playlist, counter_cache: :tracks_count
  belongs_to :track

  validates :position,
            numericality: { only_integer: true },
            uniqueness: { scope: :playlist_id }

  before_save :assign_duration
  after_create :update_playlist_duration
  after_update :update_playlist_duration
  after_destroy :update_playlist_duration

  private

  def assign_duration
    self.duration = excerpt_duration
  end

  def excerpt_duration
    start_second = starts_at_second.to_i
    end_second = ends_at_second.to_i
    dur = if start_second <= 0 && end_second <= 0
      track.duration
    elsif start_second > 0 && end_second > 0
      (end_second - start_second) * 1000
    elsif start_second > 0
      (track.duration - (start_second * 1000))
    elsif end_second > 0
      end_second * 1000
    end
    dur.negative? ? track.duration : dur
  end

  def update_playlist_duration
    playlist.update_duration
  end
end
