# frozen_string_literal: true
class Song < ApplicationRecord
  has_and_belongs_to_many :tracks

  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title

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

  scope :relevant, -> { where('tracks_count > 0 or alias_for IS NOT NULL') }
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
      updated_at: updated_at
    }
  end

  def as_json_api
    {
      id: id,
      title: title,
      alias_for: alias_for,
      tracks_count: tracks_count,
      slug: slug,
      updated_at: updated_at,
      tracks: tracks.sort_by { |t| t.show.date }.map do |t|
        {
          id: t.id,
          title: t.title,
          duration: t.duration,
          show_id: t.show.id,
          show_date: t.show.date,
          set: t.set,
          position: t.position,
          likes_count: t.likes_count,
          slug: t.slug,
          mp3: t.mp3_url
        }
      end
    }
  end
end
