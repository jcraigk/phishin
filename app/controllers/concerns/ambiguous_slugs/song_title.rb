# frozen_string_literal: true
module AmbiguousSlugs::SongTitle
  def slug_as_song
    slug = params[:slug]

    validate_song_sorting

    return false unless (@song = Song.find_by(slug: slug))

    if @song.alias_for
      aliased_song = Song.where(id: @song.alias_for).first
      @redirect = "/#{aliased_song.slug}"
    else
      @tracks = @song.tracks
                     .includes({ show: :venue }, :songs, :tags)
                     .order(@order_by)
                     .paginate(page: params[:page], per_page: 20)
      @next_song = Song.relevant.where('title > ?', @song.title).order(title: :asc).first
      @next_song ||= Song.relevant.order(title: :asc).first
      @previous_song = Song.relevant.where('title < ?', @song.title).order(title: :desc).first
      @previous_song ||= Song.relevant.order(title: :desc).first
      @tracks_likes = user_likes_for_tracks(@tracks)
      @tracks_likes = []
    end

    @view = 'songs/show'
    @ambiguous_controller = 'songs'

    true
  end

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
