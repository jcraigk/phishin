class Tag < ActiveRecord::Base
  attr_accessible :name, :description, :created_at, :updated_at
  belongs_to :show_tags
  belongs_to :track_tags
end