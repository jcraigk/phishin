# frozen_string_literal: true
class Tour < ApplicationRecord
  has_many :shows

  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: true
  validates :starts_on, presence: true, uniqueness: true
  validates :ends_on, presence: true, uniqueness: true

  def as_json
    {
      id: id,
      name: name,
      shows_count: shows_count,
      starts_on: starts_on.to_s,
      ends_on: ends_on.to_s,
      slug: slug,
      updated_at: updated_at.to_s
    }
  end

  def as_json_api
    {
      id: id,
      name: name,
      shows_count: shows_count,
      slug: slug,
      starts_on: starts_on.to_s,
      ends_on: ends_on.to_s,
      shows: shows.sort_by(&:date).as_json,
      updated_at: updated_at.to_s
    }
  end
end
