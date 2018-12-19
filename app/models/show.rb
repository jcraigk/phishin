# frozen_string_literal: true
class Show < ApplicationRecord
  belongs_to :tour, counter_cache: true
  belongs_to :venue, counter_cache: true
  has_many :tracks, dependent: :destroy
  has_many :likes, as: :likable, dependent: :destroy
  has_many :show_tags, dependent: :destroy
  has_many :tags, through: :show_tags

  extend FriendlyId
  friendly_id :date

  validates :date, presence: true
  validates :date, uniqueness: true

  default_scope { where(published: true) }

  scope :between_years, lambda { |year1, year2|
    date1 = Date.new(year1.to_i).beginning_of_year
    date2 = Date.new(year2.to_i).end_of_year
    where(date: date1..date2)
  }
  scope :during_year, lambda { |year|
    where("date_part('year', date) = ?", year)
  }
  scope :on_day_of_year, lambda { |month, day|
    where('extract(month from date) = ?', month)
      .where('extract(day from date) = ?', day)
  }
  scope :random, ->(amt = 1) { order(Arel.sql('RANDOM()')).limit(amt) }
  scope :tagged_with, ->(tag_name) { joins(:tags).where(tags: { name: tag_name }) }

  delegate :name, to: :tour, prefix: true

  def save_duration
    update(duration: tracks.map(&:duration).inject(0, &:+))
  end

  def date_with_dots
    date.strftime('%Y.%m.%d')
  end

  def venue_name
    venue.venue_renames
         .sort_by(&:renamed_on)
         .reverse
         .find { |rename| rename.renamed_on <= date }
         &.name || venue.name
  end

  def as_json # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id: id,
      date: date.iso8601,
      duration: duration,
      incomplete: incomplete,
      sbd: sbd,
      remastered: remastered,
      tour_id: tour_id,
      venue_id: venue_id,
      likes_count: likes_count,
      taper_notes: taper_notes,
      updated_at: updated_at.iso8601,
      venue_name: venue_name,
      location: venue&.location
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id: id,
      date: date.iso8601,
      duration: duration,
      incomplete: incomplete,
      sbd: sbd,
      remastered: remastered,
      tags: tags.sort_by(&:priority).map(&:name).as_json,
      tour_id: tour_id,
      venue: venue.as_json,
      venue_name: venue_name,
      taper_notes: taper_notes,
      likes_count: likes_count,
      tracks: tracks.sort_by(&:position).map(&:as_json_api),
      updated_at: updated_at.iso8601
    }
  end
end
