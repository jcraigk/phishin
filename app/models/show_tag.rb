class ShowTag < ActiveRecord::Base
  attr_accessible :show_id, :tag_id, :created_at
  belongs_to :show
  belongs_to :tag
end
