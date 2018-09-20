# frozen_string_literal: true
class Venue < ApplicationRecord
  has_many :shows

  extend FriendlyId
  friendly_id :name, use: :slugged

  geocoded_by :address

  scope :relevant, -> { where('shows_count > 0') }
  scope :name_starting_with, ->(char) { where('name SIMILAR TO ?', "#{char == '#' ? '[0-9]' : char}%") }

  def name_and_abbrev
    abbrev.present? ? "#{name} (#{abbrev})" : name
  end

  def location
    loc =
      if country == 'USA'
        "#{city}, #{state}"
      else
        "#{city}, #{state}, #{country}"
      end
    loc.gsub(/\s+/, ' ')
  end

  def address
    "#{name}, #{location}"
  end

  def name_letter
    name[0, 1]
  end

  def as_json
    {
      id: id,
      name: name,
      past_names: past_names,
      latitude: latitude,
      longitude: longitude,
      shows_count: shows_count,
      location: location,
      slug: slug,
      updated_at: updated_at
    }
  end

  def as_json_api
    {
      id: id,
      name: name,
      past_names: past_names,
      latitude: latitude,
      longitude: longitude,
      shows_count: shows_count,
      location: location,
      city: city,
      state: state,
      country: country,
      slug: slug,
      show_dates: my_shows.map(&:date),
      show_ids: my_shows.map(&:id),
      updated_at: updated_at
    }
  end

  private

  def my_shows
    @my_shows ||= shows.order('date').all
  end
end
