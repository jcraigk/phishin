# frozen_string_literal: true
class SongsTrack < ApplicationRecord
  belongs_to :track
  belongs_to :song

  after_commit :increment_song_tracks_count, on: :create
  after_commit :decrement_song_tracks_count, on: :destroy

  private

  def increment_song_tracks_count
    Song.find(song_id).increment!(:tracks_count)
  end

  def decrement_song_tracks_count
    Song.find(song_id).decrement!(:tracks_count)
  end
end
