# frozen_string_literal: true
class Playlist < ApplicationRecord
  MAX_TRACKS = 100

  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :playlist_bookmarks, dependent: :destroy
  belongs_to :user

  validates :name,
            presence: true,
            format: { with: /\A.{5,50}\z/ },
            uniqueness: true
  validates :slug,
            presence: true,
            format: {
              with: /\A[a-z0-9-]{5,50}\z/,
              message: 'must be between 5 and 50 lowercase letters, numbers, or dashes'
            },
            uniqueness: true
  validate :limit_total_tracks

  def as_json_api
    {
      slug:,
      name:,
      duration:,
      tracks: playlist_tracks.order(:position).map { |x| x.track.as_json_api },
      updated_at: updated_at.iso8601
    }
  end

  def as_json_api_basic
    {
      slug:,
      name:,
      duration:,
      track_count: playlist_tracks.size,
      updated_at: updated_at.iso8601
    }
  end

  private

  def limit_total_tracks
    return unless playlist_tracks.count > MAX_TRACKS
    errors.add(:tracks, "can't have more than #{MAX_TRACKS} tracks")
  end
end
