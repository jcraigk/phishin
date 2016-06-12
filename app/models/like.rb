class Like < ActiveRecord::Base
  attr_accessible :likable_type, :likable_id, :user_id, :created_at

  belongs_to :likable, polymorphic: true, counter_cache: true
  belongs_to :user
end
