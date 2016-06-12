class SongsTrack < ActiveRecord::Base
  belongs_to :track
  belongs_to :song

  after_create do
    Song.find(song_id).increment!(:tracks_count)
  end

  after_destroy do
    Song.find(song_id).decrement!(:tracks_count)
  end
end
