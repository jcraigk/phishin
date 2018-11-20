# frozen_string_literal: true
class Venue < ApplicationRecord
  has_many :shows

  extend FriendlyId
  friendly_id :name, use: :slugged

  geocoded_by :address

  validates :name, :city, :country, presence: true

  scope :relevant, -> { where('shows_count > 0') }
  scope :name_starting_with, lambda { |char|
    where(
      'name SIMILAR TO ?',
      "#{if char == '#'
           '[0-9]'
         else
           '(' + char.downcase + '|' + char.upcase + ')'
         end}%"
    )
  }

  def long_name
    str = name
    str += " (#{abbrev})" if abbrev.present?
    str += " (aka #{past_names})" if past_names.present?
    str
  end

  def location
    loc =
      if country == 'USA'
        "#{city}, #{state}"
      elsif state.present?
        "#{city}, #{state}, #{country}"
      else
        "#{city}, #{country}"
      end
    loc.gsub(/\s+/, ' ')
  end

  def as_json
    {
      id: id,
      name: name,
      past_names: past_names,
      latitude: latitude.round(6),
      longitude: longitude.round(6),
      shows_count: shows_count,
      location: location,
      slug: slug,
      updated_at: updated_at.to_s
    }
  end

  def as_json_api
    {
      id: id,
      name: name,
      past_names: past_names,
      latitude: latitude.round(6),
      longitude: longitude.round(6),
      shows_count: shows_count,
      location: location,
      city: city,
      state: state,
      country: country,
      slug: slug,
      show_dates: shows_played_here.map(&:date).map(&:to_s),
      show_ids: shows_played_here.map(&:id),
      updated_at: updated_at.to_s
    }
  end

  private

  def shows_played_here
    @shows_played_here ||= shows.order(date: :asc).all
  end
end
