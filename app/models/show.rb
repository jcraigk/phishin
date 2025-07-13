class Show < ApplicationRecord
  include HasCoverArt
  include ShowApiV1
  include HasAudioStatus

  belongs_to :tour, counter_cache: true
  belongs_to :venue, counter_cache: true
  has_many :tracks, dependent: :destroy
  has_many :likes, as: :likable, dependent: :destroy
  has_many :show_tags, dependent: :destroy
  has_many :tags, through: :show_tags

  has_one_attached :cover_art do |attachable|
    attachable.variant :medium,
                       resize_to_limit: [ 256, 256 ],
                       preprocessed: true
    attachable.variant :small,
                       resize_to_limit: [ 40, 40 ],
                       preprocessed: true
  end
  has_one_attached :album_cover do |attachable|
    attachable.variant :id3, resize_to_limit: [ 600, 600 ]
  end
  has_one_attached :album_zip

  extend FriendlyId
  friendly_id :date

  validates :date, presence: true, uniqueness: true

  before_validation :cache_venue_name
  after_create :increment_shows_with_audio_counter_caches
  after_destroy :decrement_shows_with_audio_counter_caches

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

  def url
    "#{App.base_url}/#{date}"
  end

  def update_audio_status_from_tracks!
    return if tracks.empty?

    statuses = tracks.pluck(:audio_status).uniq
    new_status =
      if statuses == %w[missing]
        "missing"
      elsif statuses.include?("missing")
        "partial"
      else
        "complete"
      end

    update_column(:audio_status, new_status) if audio_status != new_status
  end

  def incomplete
    audio_status == "partial" # API v1 compatibility
  end

  private

  def cache_venue_name
    return if venue_name.present?
    self.venue_name = venue.name_on(date)
  end

  def increment_shows_with_audio_counter_caches
    return unless has_audio?
    increment_shows_with_audio_counters
  end

  def decrement_shows_with_audio_counter_caches
    return unless has_audio?
    decrement_shows_with_audio_counters
  end

  def increment_shows_with_audio_counters
    venue.increment!(:shows_with_audio_count)
    tour.increment!(:shows_with_audio_count)
  end

  def decrement_shows_with_audio_counters
    venue.decrement!(:shows_with_audio_count)
    tour.decrement!(:shows_with_audio_count)
  end
end
