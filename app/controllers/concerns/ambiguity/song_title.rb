# frozen_string_literal: true
module Ambiguity::SongTitle
  def slug_as_song
    return false if song.blank?

    validate_sorting_for_tracks
    hydrate_song_page

    true
  end

  private

  def hydrate_song_page
    @previous_song = previous_song
    @next_song = next_song
    @view = 'songs/show'
    @ambiguity_controller = 'songs'
    @tracks = song.tracks
                  .includes(:songs, show: :venue, track_tags: :tag)
                  .order(@order_by)
                  .paginate(page: params[:page], per_page: 20)
    @tracks_likes = user_likes_for_tracks(@tracks)
  end

  def previous_song
    Song.where('title < ?', @song.title)
        .order(title: :desc)
        .first ||
      Song.order(title: :desc).first
  end

  def next_song
    Song.where('title > ?', @song.title)
        .order(title: :asc)
        .first ||
      Song.order(title: :asc).first
  end

  def song
    @song ||= Song.find_by(slug: current_slug)
  end
end
