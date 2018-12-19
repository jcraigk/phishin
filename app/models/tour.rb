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
      starts_on: starts_on.iso8601,
      ends_on: ends_on.iso8601,
      slug: slug,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api
    {
      id: id,
      name: name,
      shows_count: shows_count,
      slug: slug,
      starts_on: starts_on.iso8601,
      ends_on: ends_on.iso8601,
      shows: shows.sort_by(&:date).as_json,
      updated_at: updated_at.iso8601
    }
  end
end
