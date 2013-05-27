class PlaylistTrack < ActiveRecord::Base
  
  attr_accessible :playlist_id, :track_id, :position
  
  belongs_to :playlist
  belongs_to :track

  validates :position, numericality: true
  
  after_create :update_playlist_duration
  after_destroy :update_playlist_duration
  
  private
  
  def update_playlist_duration
    playlist = Playlist.find(self.playlist_id).first
    playlist.update_attributes(duration: playlist.tracks.map(&:duration).inject(0, &:+)) if playlist
  end
  
end
