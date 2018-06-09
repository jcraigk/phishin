# frozen_string_literal: true
class Tour < ApplicationRecord
  has_many :shows

  extend FriendlyId
  friendly_id :name, use: :slugged

  def as_json
    {
      id: id,
      name: name,
      shows_count: shows_count,
      starts_on: starts_on,
      ends_on: ends_on,
      slug: slug,
      updated_at: updated_at
    }
  end

  def as_json_api
    {
      id: id,
      name: name,
      shows_count: shows_count,
      slug: slug,
      starts_on: starts_on,
      ends_on: ends_on,
      shows: shows.sort_by(&:date).as_json,
      updated_at: updated_at
    }
  end
end
