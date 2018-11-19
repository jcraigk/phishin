# frozen_string_literal: true
class SongsTrack < ApplicationRecord
  belongs_to :track
  belongs_to :song, counter_cache: :tracks_count
end
