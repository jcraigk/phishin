class TrackRequest < ActiveRecord::Base
  attr_accessible :track_id, :user_id, :kind, :created_at

  has_one :user
  has_one :track
end
