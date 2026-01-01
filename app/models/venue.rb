class Venue < ApplicationRecord
  has_many :shows, dependent: :nullify
  has_many :venue_renames, dependent: :destroy

  has_one_attached :map_image

  extend FriendlyId
  friendly_id :name, use: :slugged

  geocoded_by :address

  validates :city, presence: true
  validates :country, presence: true
  validates :name, presence: true, uniqueness: { scope: :city }

  after_commit :enqueue_map_snapshot_job, on: %i[create update], if: :location_changed_for_maps?

  scope :name_starting_with, lambda { |char|
    where("LOWER(name) SIMILAR TO ?", "#{char == '#' ? '[0-9]' : char.downcase}%")
  }

  def should_generate_new_friendly_id?
    will_save_change_to_attribute?(:name) || super
  end

  def url
    "#{App.base_url}/venues/#{slug}"
  end

  def long_name
    str = name
    str += " (#{abbrev})" if abbrev.present?
    str += " (aka #{other_names_str})" if other_names.any?
    str
  end

  def other_names
    @other_names ||=
      if venue_renames.loaded?
        venue_renames.sort_by(&:renamed_on).map(&:name)
      else
        venue_renames.order(renamed_on: :asc).pluck(:name)
      end
  end

  def other_names_str
    other_names.join(", ")
  end

  def location
    loc =
      if country == "USA"
        "#{city}, #{state}"
      elsif state.present?
        "#{city}, #{state}, #{country}"
      else
        "#{city}, #{country}"
      end
    loc.gsub(/\s+/, " ")
  end

  def as_json # rubocop:disable Metrics/MethodLength
    {
      id:,
      slug:,
      name:,
      other_names:,
      latitude: latitude&.round(6),
      longitude: longitude&.round(6),
      shows_count: shows_with_audio_count,
      location:,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id:,
      slug:,
      name:,
      other_names:,
      latitude: latitude&.round(6),
      longitude: longitude&.round(6),
      location:,
      city:,
      state:,
      country:,
      shows_count: shows_with_audio_count,
      show_dates: shows_played_here.map { |x| x.date.iso8601 },
      show_ids: shows_played_here.map(&:id),
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end

  def name_on(date)
    venue_renames.where(renamed_on: ..date)
                 .order(renamed_on: :desc)
                 .first
                 &.name || name
  end

  def map_url
    blob_url(map_image, placeholder: "venue-map.png", ext: :png)
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end

  private

  def shows_played_here
    @shows_played_here ||= shows.with_audio.order(date: :asc)
  end

  def location_changed_for_maps?
    saved_change_to_latitude? || saved_change_to_longitude?
  end

  def enqueue_map_snapshot_job
    VenueMapSnapshotJob.perform_async(id)
  end
end
