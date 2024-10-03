class Show < ApplicationRecord
  belongs_to :tour, counter_cache: true
  belongs_to :venue, counter_cache: true
  has_many :tracks, dependent: :destroy
  has_many :likes, as: :likable, dependent: :destroy
  has_many :show_tags, dependent: :destroy
  has_many :tags, through: :show_tags

  has_one_attached :cover_art do |attachable|
    attachable.variant :small,
                       resize_to_limit: [ 48, 48 ],
                       preprocessed: true
  end
  has_one_attached :album_cover

  extend FriendlyId
  friendly_id :date

  validates :date, presence: true, uniqueness: true

  before_validation :cache_venue_name

  scope :between_years, lambda { |year1, year2|
    date1 = Date.new(year1.to_i).beginning_of_year
    date2 = Date.new(year2.to_i).end_of_year
    where(date: date1..date2)
  }
  scope :during_year, lambda { |year|
    where("date_part('year', date) = ?", year)
  }
  scope :on_day_of_year, lambda { |month, day|
    where("extract(month from date) = ?", month)
      .where("extract(day from date) = ?", day)
  }
  scope :published, -> { where(published: true) }
  scope :random, ->(amt = 1) { order(Arel.sql("RANDOM()")).limit(amt) }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  delegate :name, to: :tour, prefix: true

  def save_duration
    update_column(:duration, tracks.sum(&:duration))
  end

  def date_with_dots
    date.strftime("%Y.%m.%d")
  end

  def as_json # rubocop:disable Metrics/MethodLength
    {
      id:,
      date: date.iso8601,
      duration:,
      incomplete:,
      sbd: false,
      remastered: false,
      tour_id:,
      venue_id:,
      likes_count:,
      taper_notes:,
      updated_at: updated_at.iso8601,
      venue_name:,
      location: venue&.location
    }
  end

  def as_json_api # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      id:,
      date: date.iso8601,
      duration:,
      incomplete:,
      sbd: false,
      remastered: false,
      tags: show_tags_for_api,
      tour_id:,
      venue: venue.as_json,
      venue_name:,
      taper_notes:,
      likes_count:,
      tracks: tracks.sort_by(&:position).map(&:as_json_api),
      updated_at: updated_at.iso8601
    }
  end

  def url
    "#{App.base_url}/#{date}"
  end

  private

  def show_tags_for_api
    show_tags.map { |show_tag| show_tag_json(show_tag) }.sort_by { |t| t[:priority] }
  end

  def show_tag_json(show_tag)
    {
      id: show_tag.tag.id,
      name: show_tag.tag.name,
      priority: show_tag.tag.priority,
      group: show_tag.tag.group,
      color: show_tag.tag.color,
      notes: show_tag.notes
    }
  end

  def cache_venue_name
    return if venue_name.present?
    self.venue_name = venue.name_on(date)
  end
end
