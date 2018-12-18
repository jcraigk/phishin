# frozen_string_literal: true
class Song < ApplicationRecord
  has_and_belongs_to_many :tracks

  extend FriendlyId
  friendly_id :title, use: :slugged

  validates :title, presence: true, uniqueness: true

  include PgSearch
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
    where(
      'title SIMILAR TO ?',
      "#{if char == '#'
           '[0-9]'
         else
           '(' + char.downcase + '|' + char.upcase + ')'
         end}%"
    )
  }
  scope :with_lyrical_excerpt, -> { where.not(lyrical_excerpt: nil) }

  def self.random_with_lyrical_excerpt
    where.not(lyrical_excerpt: nil).order(Arel.sql('RANDOM()')).first
  end

  def aliased_song
    Song.where(id: alias_for).first
  end

  def alias?
    alias_for.present?
  end

  def as_json
    {
      id: id,
      title: title,
      alias_for: alias_for,
      tracks_count: tracks_count,
      slug: slug,
      updated_at: updated_at.to_s
    }
  end

  def as_json_api
    {
      id: id,
      title: title,
      alias_for: alias_for,
      tracks_count: tracks_count,
      slug: slug,
      updated_at: updated_at.to_s,
      tracks: tracks.sort_by { |t| t.show.date }.map(&:as_json_api)
    }
  end
end
