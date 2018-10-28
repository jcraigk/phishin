# frozen_string_literal: true
class Playlist < ApplicationRecord
  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :playlist_bookmarks, dependent: :destroy
  belongs_to :user

  validates :name, presence: true
  validates :slug, presence: true

  def as_json_api
    {
      slug: slug,
      name: name,
      duration: duration,
      tracks: playlist_tracks.order(:position).map(&:as_json_api),
      updated_at: updated_at
    }
  end

  def as_json_api_basic
    {
      slug: slug,
      name: name,
      duration: duration,
      track_count: playlist_tracks.size,
      updated_at: updated_at
    }
  end
end
