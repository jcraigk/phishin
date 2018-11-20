# frozen_string_literal: true
class Tag < ApplicationRecord
  has_many :show_tags
  has_many :shows, through: :show_tags
  has_many :track_tags
  has_many :tracks, through: :track_tags

  validates :name, :color, :priority, presence: true
  validates :priority, uniqueness: true

  extend FriendlyId
  friendly_id :name, use: :slugged

  def as_json
    {
      id: id,
      name: name,
      slug: slug,
      description: description,
      updated_at: updated_at.to_s
    }
  end

  def as_json_api
    {
      id: id,
      name: name,
      slug: slug,
      description: description,
      updated_at: updated_at.to_s,
      show_ids: shows.map(&:id),
      track_ids: tracks.map(&:id)
    }
  end
end
