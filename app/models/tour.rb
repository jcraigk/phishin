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
      shows_count: shows_with_audio_count,
      starts_on: starts_on.iso8601,
      ends_on: ends_on.iso8601,
      slug:,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api
    {
      id:,
      name:,
      shows_count: shows_with_audio_count,
      slug:,
      starts_on: starts_on.iso8601,
      ends_on: ends_on.iso8601,
      shows: shows.sort_by(&:date).as_json,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end
end
