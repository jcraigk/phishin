class Like < ApplicationRecord
  belongs_to :likable, polymorphic: true, counter_cache: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: %i[ likable_id likable_type ] }
end
