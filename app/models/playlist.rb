class Playlist < ApplicationRecord
  MAX_TRACKS = 250

  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :likes, as: :likable, dependent: :destroy
  belongs_to :user
  belongs_to :cover_art_track, class_name: "Track", optional: true

  accepts_nested_attributes_for :playlist_tracks, allow_destroy: true

  validates :name,
            presence: true,
            format: { with: /\A.{5,50}\z/ },
            uniqueness: true
  validates :description,
            length: { maximum: 500 }
  validates :slug,
            presence: true,
            format: {
              with: /\A[a-z0-9-]{5,50}\z/,
              message: "must be between 5 and 50 lowercase letters, numbers, or dashes"
            },
            uniqueness: true
  before_validation :default_cover_art_track
  validate :validate_tracks_count
  validate :validate_cover_art_track

  scope :published, -> { where(published: true) }

  def url
    "#{App.base_url}/play/#{slug}"
  end

  after_save :save_duration

  def save_duration
    update_column(:duration, playlist_tracks.sum(:duration)) if self.persisted?
  end

  def cover_art_urls
    cover_art_track&.show&.cover_art_urls
  end

  def reset_cover_art_track
    playlist_tracks.reset
    update_column(:cover_art_track_id, first_track_id) if cover_art_track_missing?
  end

  def as_json_api
    {
      slug:,
      name:,
      duration:,
      tracks: playlist_tracks.order(:position).map { |x| x.track.as_json_api },
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api_basic
    {
      slug:,
      name:,
      duration:,
      track_count: playlist_tracks.size,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end

  private

  def default_cover_art_track
    self.cover_art_track_id = first_track_id if cover_art_track_id.nil?
  end

  def validate_cover_art_track
    return unless cover_art_track_missing?
    errors.add(:cover_art_track_id, "must be a track in the playlist")
  end

  def cover_art_track_missing?
    playlist_tracks.none? { |pt| pt.track_id == cover_art_track_id }
  end

  def first_track_id
    playlist_tracks.reject(&:marked_for_destruction?).min_by(&:position)&.track_id
  end

  def validate_tracks_count
    if playlist_tracks.size > MAX_TRACKS
      errors.add(:tracks, "can't number more than #{MAX_TRACKS}")
    elsif playlist_tracks.size < 2
      errors.add(:tracks, "must number at least 2")
    end
  end
end
