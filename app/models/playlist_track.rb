class PlaylistTrack < ApplicationRecord
  belongs_to :playlist
  belongs_to :track

  validates :position,
            numericality: { only_integer: true },
            uniqueness: { scope: :playlist_id }
end
