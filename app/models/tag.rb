# frozen_string_literal: true
class Tag < ApplicationRecord
  has_many :show_tags
  has_many :shows, through: :show_tags
  has_many :track_tags
  has_many :tracks, through: :track_tags

  def as_json
    {
      id: id,
      name: name,
      description: description,
      updated_at: updated_at
    }
  end
end
