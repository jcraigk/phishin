class TrackTag < ApplicationRecord
  belongs_to :track, counter_cache: :tags_count
  belongs_to :tag, counter_cache: :tracks_count
end
