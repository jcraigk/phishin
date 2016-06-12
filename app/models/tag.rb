class Tag < ActiveRecord::Base
  attr_accessible :name, :description, :color, :created_at, :updated_at
  belongs_to :show_tags
  belongs_to :track_tags

  def as_json
    {
      id: id,
      name: name,
      description: description,
      last_modified: updated_at
    }
  end
end
