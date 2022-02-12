# frozen_string_literal: true
class Tour < ApplicationRecord
  has_many :shows, dependent: :nullify

  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: true
  validates :starts_on, presence: true, uniqueness: true
  validates :ends_on, presence: true, uniqueness: true

  def as_json
    {
      id:,
      name:,
      shows_count:,
      starts_on: starts_on.iso8601,
      ends_on: ends_on.iso8601,
      slug:,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api
    {
      id:,
      name:,
      shows_count:,
      slug:,
      starts_on: starts_on.iso8601,
      ends_on: ends_on.iso8601,
      shows: shows.sort_by(&:date).as_json,
      updated_at: updated_at.iso8601
    }
  end
end
