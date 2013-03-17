class Request < ActiveRecord::Base
  
  attr_accessible :track_id, :user_id, :type, :created_at
  
  has_one :user
  has_one :track
  
end
