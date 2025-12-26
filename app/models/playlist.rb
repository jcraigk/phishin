class Playlist < ApplicationRecord
  MAX_TRACKS = 250

  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :likes, as: :likable, dependent: :destroy
  belongs_to :user

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
  validate :validate_tracks_count

  scope :published, -> { where(published: true) }

  def url
    "#{App.base_url}/play/#{slug}"
  end

  after_save :save_duration

  def save_duration
    update_column(:duration, playlist_tracks.sum(:duration)) if self.persisted?
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

  def validate_tracks_count
    if playlist_tracks.size > MAX_TRACKS
      errors.add(:tracks, "can't number more than #{MAX_TRACKS}")
    elsif playlist_tracks.size < 2
      errors.add(:tracks, "must number at least 2")
    end
  end
end
