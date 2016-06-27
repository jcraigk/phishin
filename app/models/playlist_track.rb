class PlaylistTrack < ActiveRecord::Base
  attr_accessible :playlist_id, :track_id, :position

  belongs_to :playlist
  belongs_to :track

  validates :position, numericality: true

  def as_json_for_api
    {
      position: position,
      id: track_id,
      show_id: track.show_id,
      show_date: track.show.date,
      title: track.title,
      duration: track.duration,
      set: track.set,
      set_name: track.set_name,
      likes_count: track.likes_count,
      slug: track.slug,
      tags: track.tags.sort_by(&:priority).map(&:name).as_json,
      mp3: track.mp3_url,
      song_ids: track.songs.map(&:id)
    }
  end
end
