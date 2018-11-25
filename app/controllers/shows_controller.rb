# frozen_string_literal: true
module AmbiguousSlugAsShow
  def slug_as_show
    date = params[:slug]

    # convert 2012.12.31 to 2012-12-31
    r = Regexp.last_match
    date = "#{r[1]}-#{r[2]}-#{r[3]}" if date =~ /\A(\d{4})\.(\d{1,2})\.(\d{1,2})\z/

    @show = Show.includes(tracks: %i[songs tags]).find_by!(date: date)

    @sets = {}
    tracks = @show.tracks
    tracks.group_by(&:set_name).each do |set, track_list|
      @sets[set] = {
        duration: track_list.map(&:duration).inject(0, &:+),
        tracks: track_list,
        likes: user_likes_for_tracks(track_list)
      }
    end
    @show_like = user_likes_for_shows([@show])
    @show_like = nil

    set_next_show
    set_previous_show

    render_xhr_without_layout
    render layout: false if request.xhr?

  end

  def set_next_show
    @next_show =
      Show.avail
          .where('date > ?', @show.date)
          .order(date: :asc)
          .first
    @next_show ||=
      Show.avail
          .order(date: :asc)
          .first
  end

  def set_previous_show
    @previous_show =
      Show.avail
          .where('date < ?', @show.date)
          .order(date: :desc)
          .first
    @previous_show ||=
      Show.avail
          .order(date: :desc)
          .first if @previous_show.nil?
  end
end