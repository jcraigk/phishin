# frozen_string_literal: true
class Show < ApplicationRecord
  belongs_to :tour, counter_cache: true
  belongs_to :venue, counter_cache: true
  has_many :tracks, dependent: :destroy
  has_many :likes, as: :likable, dependent: :destroy
  has_many :show_tags, dependent: :destroy
  has_many :tags, through: :show_tags

  validates :date, presence: true

  self.per_page = 10 # will_paginate default

  extend FriendlyId
  friendly_id :date

  scope :avail, -> { where('missing = FALSE') }
  scope :tagged_with, ->(tag) { includes(:tags).where('tags.name = ?', tag) }

  scope :during_year, lambda(year) {
    date = Date.new(year.to_i)
    where(
      'date between ? and ?',
      date.beginning_of_year,
      date.end_of_year
    )
  }
  scope :between_years, lambda(year1, year2) {
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
  scope :random, ->(amt = 1) { order('RAND()').limit(amt) }

  def to_s
    if venue
      "#{date.strftime('%Y-%m-%d')} - #{venue.name} - #{venue.location}"
    else
      "#{date.strftime('%Y-%m-%d')} - NULL VENUE!"
    end
  end

  def last_set
    tracks.select {|t| /^\d$/.match t.set }.map(&:set).sort.last
  end

  def as_json
    hash = {
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
      updated_at: updated_at
    }
    hash.merge(
      venue_name: venue.name,
      location: venue.location
    ) if venue
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
      tags: tags.map(&:name).as_json,
      tour_id: tour_id,
      venue: venue.as_json,
      taper_notes: taper_notes,
      likes_count: likes_count,
      tracks: tracks.sort_by(&:position).as_json,
      updated_at: updated_at
    }
  end

  def save_duration
    duration = 0
    tracks.each { |t| duration += t.duration }
    self.duration = duration
    save
  end
end
