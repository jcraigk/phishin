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

  scope :avail, -> { where(missing: false) }
  scope :tagged_with, ->(tag_name) { includes(:tags).where(tags: { name: tag_name }) }

  scope :during_year, lambda { |year|
    date = Date.new(year.to_i)
    where(
      'date between ? and ?',
      date.beginning_of_year,
      date.end_of_year
    )
  }
  scope :between_years, lambda { |year1, year2|
    date1 = Date.new(year1.to_i)
    date2 = Date.new(year2.to_i)
    if date1 < date2
      where(
        'date between ? and ?',
        date1.beginning_of_year,
        date2.end_of_year
      )
    else
      where(
        'date between ? and ?',
        date2.beginning_of_year,
        date1.end_of_year
      )
    end
  }
  scope :on_day_of_year, lambda { |month, day|
    where('extract(month from date) = ?', month)
      .where('extract(day from date) = ?', day)
  }

  delegate :name, to: :tour, prefix: true

  def save_duration
    update(duration: tracks.map(&:duration).inject(0, &:+))
  end

  def as_json
    {
      id: id,
      date: date,
      duration: duration,
      incomplete: incomplete,
      missing: missing,
      sbd: sbd,
      remastered: remastered,
      tour_id: tour_id,
      venue_id: venue_id,
      likes_count: likes_count,
      taper_notes: taper_notes,
      updated_at: updated_at,
      venue_name: venue&.name,
      location: venue&.location
    }
  end

  def as_json_api
    {
      id: id,
      date: date,
      duration: duration,
      incomplete: incomplete,
      missing: missing,
      sbd: sbd,
      remastered: remastered,
      tags: tags.sort_by(&:priority).map(&:name).as_json,
      tour_id: tour_id,
      venue: venue.as_json,
      taper_notes: taper_notes,
      likes_count: likes_count,
      tracks: tracks.sort_by(&:position).map(&:as_json_api),
      updated_at: updated_at
    }
  end
end
