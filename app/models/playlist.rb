class Playlist < ActiveRecord::Base
  attr_accessible :name, :slug, :user_id, :duration

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
      tracks: playlist_tracks.order(:position).map(&:as_json_for_api),
      last_modified: updated_at
    }
  end

  def as_json_api_basic
    {
      slug: slug,
      name: name,
      duration: duration,
      track_count: playlist_tracks.size,
      last_modified: updated_at
    }
  end
end
