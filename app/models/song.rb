# frozen_string_literal: true
class Song < ApplicationRecord
  has_many :songs_tracks, dependent: :destroy
  has_many :tracks, through: :songs_tracks

  extend FriendlyId
  friendly_id :title, use: :slugged

  validates :title, presence: true, uniqueness: true
  validates :alias, uniqueness: true, allow_nil: true

  include PgSearch::Model
  pg_search_scope(
    :kinda_matching,
    against: :title,
    using: {
      tsearch: {
        any_word: true,
        normalization: 16
      }
    }
  )

  scope :title_starting_with, lambda { |char|
    where('LOWER(title) SIMILAR TO ?', "#{char == '#' ? '[0-9]' : char.downcase}%")
  }
  scope :with_lyrical_excerpt, -> { where.not(lyrical_excerpt: nil) }

  def self.random_with_lyrical_excerpt
    where.not(lyrical_excerpt: nil).order(Arel.sql('RANDOM()')).first
  end

  def as_json
    {
      id: id,
      title: title,
      alias: self.alias,
      tracks_count: tracks_count,
      slug: slug,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api
    {
      id: id,
      title: title,
      alias: self.alias,
      tracks_count: tracks_count,
      slug: slug,
      updated_at: updated_at.iso8601,
      tracks: tracks.sort_by { |t| t.show.date }.map(&:as_json_api)
    }
  end
end
