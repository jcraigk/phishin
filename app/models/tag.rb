# frozen_string_literal: true
class Tag < ApplicationRecord
  belongs_to :show_tags
  belongs_to :track_tags

  def as_json
    {
      id: id,
      name: name,
      description: description,
      updated_at: updated_at
    }
  end
end
