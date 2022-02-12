# frozen_string_literal: true
class Tag < ApplicationRecord
  has_many :show_tags, dependent: :destroy
  has_many :shows, through: :show_tags
  has_many :track_tags, dependent: :destroy
  has_many :tracks, through: :track_tags

  validates :name, :color, :priority, presence: true
  validates :name, :priority, uniqueness: true

  extend FriendlyId
  friendly_id :name, use: :slugged

  def as_json
    {
      id:,
      name:,
      slug:,
      group:,
      color:,
      priority:,
      description:,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api # rubocop:disable Metrics/MethodLength
    {
      id:,
      name:,
      slug:,
      group:,
      color:,
      priority:,
      description:,
      updated_at: updated_at.iso8601,
      show_ids: shows.sort_by(&:id).map(&:id),
      track_ids: tracks.sort_by(&:id).map(&:id)
    }
  end
end
