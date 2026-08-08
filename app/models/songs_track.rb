class SongsTrack < ApplicationRecord
  belongs_to :track, touch: true
  belongs_to :song, counter_cache: :tracks_count

  validates :song, uniqueness: { scope: :track_id }
end
