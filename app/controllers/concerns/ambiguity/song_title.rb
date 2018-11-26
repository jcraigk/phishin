# frozen_string_literal: true
module Ambiguity::SongTitle
  def slug_as_song
    return false unless song.present?

    validate_song_sorting
    hydrate_song_or_redirect

    true
  end

  private

  def hydrate_song_or_redirect
    return @redirect = "/#{aliased_song.slug}" if @song.alias_for
    hydrate_song_page
    @previous_song = previous_song
    @next_song = next_song
  end

  def hydrate_song_page
    @view = 'songs/show'
    @ambiguity_controller = 'songs'
    @tracks =
      @song.tracks
           .includes({ show: :venue }, :songs, :tags)
           .order(@order_by)
           .paginate(page: params[:page], per_page: 20)
    @tracks_likes = user_likes_for_tracks(@tracks)
  end

  def previous_song
    Song.relevant
        .where('title < ?', @song.title)
        .order(title: :desc)
        .first ||
      Song.relevant
          .order(title: :desc)
          .first
  end

  def next_song
    Song.relevant
        .where('title > ?', @song.title)
        .order(title: :asc)
        .first ||
      Song.relevant
          .order(title: :asc)
          .first
  end

  def aliased_song
    Song.find_by(id: @song.alias_for)
  end

  def song
    @song ||= Song.find_by(slug: current_slug)
  end

  # TODO: This is broken :(
  def validate_song_sorting
    params[:sort] = 'date desc' unless params[:sort].in?(['date desc', 'date asc', 'likes', 'duration'])
    @order_by =
      if params[:sort].in?(['date asc', 'date desc'])
        params[:sort].gsub(/date/, 'shows.date')
      elsif params[:sort] == 'likes'
        'tracks.likes_count desc, shows.date desc'
      elsif params[:sort] == 'duration'
        'tracks.duration, shows.date desc'
      end
  end
end
