module Ambiguity::SongTitle
  def slug_as_song
    return false if song.blank?

    validate_sorting_for_tracks
    hydrate_song_page

    true
  end

  private

  def hydrate_song_page
    @ogp_title = "Listen to versions of #{song.title}"
    @previous_song = previous_song
    @next_song = next_song
    @view = 'songs/show'
    @ambiguity_controller = 'songs'
    @tracks = fetch_song_tracks
    @tracks_likes = user_likes_for_tracks(@tracks)
  end

  def fetch_song_tracks
    tracks = song.tracks.includes(:songs, show: :venue, track_tags: :tag).order(@order_by)
    tracks = tagged_tracks(tracks)
    params[:page] = constrained_page_param(tracks)
    tracks.paginate(page: params[:page], per_page: params[:per_page].presence || 20)
  end

  def constrained_page_param(tracks)
    [tracks.paginate(page: 1).total_pages, params[:page]&.to_i || 1].min
  end

  def tagged_tracks(tracks)
    return tracks if params[:tag_slug].blank? || params[:tag_slug] == 'all'
    tracks.tagged_with(params[:tag_slug])
  end

  def previous_song
    Song.where(title: ...@song.title)
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
