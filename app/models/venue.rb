class Venue < ApplicationRecord
  has_many :shows, dependent: :nullify
  has_many :venue_renames, dependent: :destroy

  extend FriendlyId
  friendly_id :name, use: :slugged

  geocoded_by :address

  validates :city, presence: true
  validates :country, presence: true
  validates :name, presence: true, uniqueness: { scope: :city }

  scope :name_starting_with, lambda { |char|
    where('LOWER(name) SIMILAR TO ?', "#{char == '#' ? '[0-9]' : char.downcase}%")
  }

  def should_generate_new_friendly_id?
    will_save_change_to_attribute?(:name) || super
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
      id:,
      slug:,
      name:,
      other_names:,
      latitude: latitude.round(6),
      longitude: longitude.round(6),
      shows_count:,
      location:,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id:,
      slug:,
      name:,
      other_names:,
      latitude: latitude.round(6),
      longitude: longitude.round(6),
      location:,
      city:,
      state:,
      country:,
      shows_count:,
      show_dates: shows_played_here.map { |x| x.date.iso8601 },
      show_ids: shows_played_here.map(&:id),
      updated_at: updated_at.iso8601
    }
  end

  def name_on(date)
    venue_renames.where(renamed_on: ..date)
                 .order(renamed_on: :desc)
                 .first
                 &.name || name
  end

  private

  def shows_played_here
    @shows_played_here ||= shows.order(date: :asc)
  end
end
