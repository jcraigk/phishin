class TrackTag < ActiveRecord::Base
  attr_accessible :track_id, :tag_id, :created_at
  belongs_to :track
  belongs_to :tag
end
