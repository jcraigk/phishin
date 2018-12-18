# frozen_string_literal: true
class Venue < ApplicationRecord
  has_many :shows
  has_many :venue_renames, dependent: :destroy

  extend FriendlyId
  friendly_id :name, use: :slugged

  geocoded_by :address

  validates :city, presence: true
  validates :country, presence: true
  validates :name, presence: true, uniqueness: { scope: :city }

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

  def should_generate_new_friendly_id?
    will_save_change_to_attribute?(:name) || super
  end

  def name_on_date(date)
    venue_renames.where('renamed_on <= ?', date)
                 .order(renamed_on: :desc)
                 .first
                 &.name || name
  end

  def long_name
    str = name
    str += " (#{abbrev})" if abbrev.present?
    str += " (aka #{other_names_str})" if other_names.any?
    str
  end

  def other_names
    @other_names ||=
      venue_renames.order(renamed_on: :asc)
                   .each_with_object([]) do |rename, other_names|
        other_names << rename.name
      end
  end

  def other_names_str
    other_names.join(', ')
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

  def as_json # rubocop:disable Metrics/MethodLength
    {
      id: id,
      slug: slug,
      name: name,
      other_names: other_names,
      latitude: latitude.round(6),
      longitude: longitude.round(6),
      shows_count: shows_count,
      location: location,
      updated_at: updated_at.to_s
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id: id,
      slug: slug,
      name: name,
      other_names: other_names,
      latitude: latitude.round(6),
      longitude: longitude.round(6),
      location: location,
      city: city,
      state: state,
      country: country,
      shows_count: shows_count,
      show_dates: shows_played_here.map(&:date).map(&:to_s),
      show_ids: shows_played_here.map(&:id),
      updated_at: updated_at.to_s
    }
  end

  private

  def shows_played_here
    @shows_played_here ||= shows.order(date: :asc)
  end
end
